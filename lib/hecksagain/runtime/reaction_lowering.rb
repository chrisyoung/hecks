require_relative "../bluebook/expression/evaluator"
require_relative "../bluebook/expression/binding_lowering"
require_relative "saga_interpreter"

module Hecksagain
  module Runtime
    # PRD 12 (ADR 0030 Slice 3, design) — the `Reaction` executable
    # shape, and the two lowering functions that produce it from a real
    # canonical `Policy`/`ProcessManager` leg. `ReactionExecutor`
    # (`reaction_executor.rb`, sibling file) is what actually RUNS one;
    # this file only builds the data.
    module ReactionLowering
      # `dispatches` — a list of `Dispatch`, NOT two parallel lists.
      # REAL FIX, found building the executor: a saga leg's own
      # `handler.dispatches` can fire SEVERAL commands, each with its
      # OWN `with_spec` — Settlement's own leg dispatches `Wire::Moved`
      # (`with: { wire: :reference }`) and `Drawer::Put` (`with: {
      # number: :destination, amount: :amount, reference: :reference
      # }`), two DIFFERENT binding sets. An earlier draft of this file
      # flattened every dispatch's bindings into one shared list on
      # `Reaction` itself — harmless for the shape-only provenance test
      # (nothing there ever resolved a binding against a real dispatch),
      # actively wrong for an executor that has to know WHICH bindings
      # belong to WHICH command. Caught before the executor shipped, not
      # after.
      Reaction = Struct.new(:trigger, :condition, :dispatches, :context, :persistence, :failure, keyword_init: true)

      # `qualifier` — the emitting AGGREGATE's own name, when `on_event`
      # was written qualified ("Account.AccountFrozen"); `nil` for a
      # bare, same-domain event name and for every process-manager leg
      # (`Behaviour::Policy#event_qualifier`, read directly).
      Trigger = Struct.new(:name, :qualifier, keyword_init: true)

      # `domain` — `nil` means "the reacting policy's own domain," the
      # same fallback `PolicyInterpreter#deliver`'s own `target` string
      # already builds (`policy.target_domain || domain`) and a process-
      # manager leg's own dispatch never needs at all (`SagaInterpreter#
      # qualified` only prefixes a domain when the command name doesn't
      # already carry one).
      CommandRef = Struct.new(:domain, :command_name, keyword_init: true)

      # ONE dispatch this `Reaction` fires — its own target and its own
      # bindings, resolved together at execution time. `bindings` is a
      # list of `BindingLowering::ExecutableBinding` — the SAME node
      # type for a policy's single dispatch and every one of a saga
      # leg's several, never a policy-shaped list and a saga-shaped one.
      Dispatch = Struct.new(:command_ref, :bindings, keyword_init: true)

      module Context
        Stateless  = Class.new
        Correlated = Struct.new(:correlation_key, :memory, keyword_init: true)
      end

      module Persistence
        Ephemeral    = Class.new
        # `to_state` — the REAL missing piece a first draft of this file
        # left out, caught building the executor: `advance_saga`'s own
        # checkpoint doesn't just record a fact, it MOVES the instance to
        # `handler.to_state` before any dispatch runs — and the
        # compensating leg's OWN guard (`unwind`'s `instance[:state] ==
        # handler.from_state`) checks against THAT already-moved state,
        # not the state the triggering leg started in. Without `to_state`
        # here, an executor has the boundary right (checkpoint before
        # dispatch) but nothing to advance the state TO, so a
        # compensating leg's own guard never matches and compensation
        # silently never fires — found by `spec/reaction_executor_spec.rb`
        # actually failing (a shut drawer's refusal never credited the
        # source drawer back), not by inspection.
        Checkpointed = Struct.new(:boundary, :to_state, keyword_init: true)
      end

      module Failure
        Drop    = Class.new
        Managed = Struct.new(:retry, :compensation, keyword_init: true)
      end

      module_function

      # THE ONE CONDITION EVALUATOR, called identically for a `policy`'s
      # own `where` and a `process_manager` leg's own state-equality
      # guard — no branch anywhere on which canonical construct produced
      # `reaction`. `condition: nil` (an unconditional policy — most of
      # them) is a real, explicit third case, not an edge case
      # `Evaluator` itself needs to know about — matches `where_holds?`'s
      # own existing precedent (`policy_interpreter.rb`) of treating an
      # absent condition as unconditionally true without ever
      # manufacturing a fake "true" AST node for it.
      def evaluate_condition(reaction, state, attrs)
        return true if reaction.condition.nil?

        Bluebook::Expression::Evaluator.interpret(reaction.condition, state, attrs)
      end

      # A REAL canonical `Policy` (`Bluebook::Policy`, read straight off
      # a loaded registry) → a bare `Reaction`. `dispatches` is a
      # ONE-ELEMENT list — the case ADR 0029's own step 4 (`trigger_command`
      # → `dispatches: [...]`) would generalize to several, not attempted
      # here — sketched as already-plural so the executor never needs to
      # know which kind of `Reaction` it's holding.
      def lower_policy(policy)
        bindings = policy.with_spec.map { |key, value| Bluebook::Expression::BindingLowering.lower([key, value], available_sources: [:payload]) }

        Reaction.new(
          trigger:     Trigger.new(name: policy.event_name, qualifier: policy.event_qualifier),
          condition:   policy.where.to_s.empty? ? nil : Bluebook::Expression::Evaluator.parse(policy.where),
          dispatches:  [Dispatch.new(command_ref: CommandRef.new(domain: policy.target_domain, command_name: policy.trigger_command), bindings: bindings)],
          context:     Context::Stateless.new,
          persistence: Persistence::Ephemeral.new,
          failure:     Failure::Drop.new
        )
      end

      # A REAL canonical `ProcessManager` leg (one `ProcessManagerHandler`,
      # off a loaded registry) → a bare `Reaction`. The guard —
      # `instance[:state] == handler.from_state` in `SagaInterpreter#
      # advance_saga` — is built here as a REAL `Evaluator::Compare`
      # node (`Equal(Reference(:state), Literal(from_state))`), exactly
      # ADR 0030's own "third finding": a process-manager guard is an
      # ordinary instance of the same `Expression` primitive a policy's
      # own `where` already is, not a structurally different check.
      #
      # `compensation` recurses into the SAME function for the `on
      # :refused` handler, if one exists and isn't this very handler
      # (a compensating leg cannot compensate itself — confirmed against
      # the real corpus, not just guarded defensively: every process
      # manager in banking.bluebook/settlement.bluebook has AT MOST one
      # `:refused` handler, so this recursion terminates after exactly
      # one level everywhere it's ever actually exercised).
      def lower_process_manager_leg(pm, handler)
        refused_handler = pm.handler_for(SagaInterpreter::REFUSED)
        compensation = refused_handler && !refused_handler.equal?(handler) ? lower_process_manager_leg(pm, refused_handler) : nil

        dispatches = handler.dispatches.map do |d|
          bindings = d.with_spec.map { |key, value| Bluebook::Expression::BindingLowering.lower([key, value], available_sources: %i[correlation payload memory]) }
          Dispatch.new(command_ref: CommandRef.new(domain: nil, command_name: d.command_name), bindings: bindings)
        end

        Reaction.new(
          trigger:     Trigger.new(name: handler.event_type, qualifier: nil),
          condition:   state_equals(handler.from_state),
          dispatches:  dispatches,
          context:     Context::Correlated.new(correlation_key: pm.correlates_by, memory: true),
          persistence: Persistence::Checkpointed.new(boundary: :before_dispatch, to_state: handler.to_state),
          failure:     Failure::Managed.new(retry: SagaInterpreter::MAX_DEFECT_RETRIES, compensation: compensation)
        )
      end

      def state_equals(from_state)
        equal_operator = Bluebook::Expression::Evaluator::OPERATORS.find { |op| op.symbol == "==" }
        Bluebook::Expression::Evaluator::Compare.new(
          operator: equal_operator,
          left:     Bluebook::Expression::Resolver::Lookup.new(path: "state"),
          right:    Bluebook::Expression::Resolver::StringLiteral.new(value: from_state)
        )
      end
    end
  end
end

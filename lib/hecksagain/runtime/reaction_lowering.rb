require_relative "../primal_ir"
require_relative "../bluebook/expression/evaluator"
require_relative "../bluebook/expression/binding_lowering"
require_relative "saga_interpreter"

module Hecksagain
  module Runtime
    # PRD 12 (ADR 0030 Slice 3) — the two lowering functions that build
    # a `PrimalIR::Reaction` (`../primal_ir.rb`, sibling concern — the
    # shape itself) from a real canonical `Policy`/`ProcessManager` leg.
    # `ReactionExecutor` (`reaction_executor.rb`, sibling file) is what
    # actually RUNS one; this file only builds the data.
    module ReactionLowering
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
      # a loaded registry) → a bare `PrimalIR::Reaction`. `dispatches` is
      # a ONE-ELEMENT list — the case ADR 0029's own step 4 (`trigger_command`
      # → `dispatches: [...]`) would generalize to several, not attempted
      # here — sketched as already-plural so the executor never needs to
      # know which kind of `Reaction` it's holding.
      def lower_policy(policy)
        bindings = if policy.with_spec.to_a.empty?
                     PrimalIR::Dispatch::VERBATIM
                   else
                     policy.with_spec.map { |key, value| Bluebook::Expression::BindingLowering.lower([key, value], available_sources: [:payload]) }
                   end

        PrimalIR::Reaction.new(
          trigger:     PrimalIR::Trigger.new(name: policy.event_name, qualifier: policy.event_qualifier),
          condition:   policy.where.to_s.empty? ? nil : Bluebook::Expression::Evaluator.parse(policy.where),
          dispatches:  [PrimalIR::Dispatch.new(command_ref: PrimalIR::CommandRef.new(domain: policy.target_domain, command_name: policy.trigger_command), bindings: bindings)],
          context:     PrimalIR::Context::Stateless.new,
          persistence: PrimalIR::Persistence::Ephemeral.new,
          failure:     PrimalIR::Failure::Drop.new
        )
      end

      # A REAL canonical `ProcessManager` leg (one `ProcessManagerHandler`,
      # off a loaded registry) → a bare `PrimalIR::Reaction`. The guard —
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
          PrimalIR::Dispatch.new(command_ref: PrimalIR::CommandRef.new(domain: nil, command_name: d.command_name), bindings: bindings)
        end

        PrimalIR::Reaction.new(
          trigger:     PrimalIR::Trigger.new(name: handler.event_type, qualifier: nil),
          condition:   state_equals(handler.from_state),
          dispatches:  dispatches,
          context:     PrimalIR::Context::Correlated.new(correlation_key: pm.correlation_head, memory: true,
                                                         lifecycle: PrimalIR::Lifecycle::Continue.new),
          persistence: PrimalIR::Persistence::Checkpointed.new(boundary: :before_dispatch, to_state: handler.to_state),
          failure:     PrimalIR::Failure::Managed.new(retry: SagaInterpreter::MAX_DEFECT_RETRIES, compensation: compensation)
        )
      end

      # A REAL canonical `ProcessManager` → the bare `PrimalIR::Reaction`
      # that CREATES one of its instances — `SagaInterpreter#begin_saga`'s
      # own trigger (`pm.starts_on`) and initial state (`pm.states.
      # first`), lowered for real instead of read off `pm` directly, the
      # real gap `Lifecycle`'s own header names (outside review, not
      # inspection: `begin_saga` never went through `Reaction` at all
      # before this). `condition: nil` — unconditional, the same as an
      # unconditional `policy`: there IS a real gate (an instance must
      # not already exist for this correlation), but it is an EXISTENCE
      # check against `@registry.saga_instances`, not a value comparison
      # against already-resolved `state`/`attrs` `Evaluator.interpret`
      # can express — and `Reaction` genuinely cannot know the owning
      # process manager's own NAME (the registry's own keying field),
      # only `correlation_key` (a FIELD name). That gate stays real,
      # hand-written orchestration in `SagaInterpreter#begin_saga`, on
      # purpose — the same reason `for_each`'s own query resolution
      # stays hand-written in `PolicyInterpreter` rather than forced
      # into this shape. `dispatches: []` — birth fires no command of
      # its own. `persistence: Checkpointed` fits cleanly even though
      # nothing is MOVING from a prior state — `to_state: pm.states.
      # first` is simply the first state this instance is ever
      # persisted at, and `ReactionExecutor#match_and_checkpoint?`
      # already handles "persist `state[:state]` unconditionally, no
      # prior value to compare against" correctly as-is (`condition:
      # nil` makes the match trivially true).
      def lower_process_manager_begin(pm)
        PrimalIR::Reaction.new(
          trigger:     PrimalIR::Trigger.new(name: pm.starts_on, qualifier: nil),
          condition:   nil,
          dispatches:  [],
          context:     PrimalIR::Context::Correlated.new(correlation_key: pm.correlation_head, memory: false,
                                                         lifecycle: PrimalIR::Lifecycle::Begin.new),
          persistence: PrimalIR::Persistence::Checkpointed.new(boundary: :before_dispatch, to_state: pm.states.first),
          failure:     PrimalIR::Failure::Drop.new
        )
      end

      # The bare `PrimalIR::Reaction` that ENDS one of a `ProcessManager`'s
      # instances — `SagaInterpreter#end_saga`'s own trigger
      # (`pm.ends_on`), lowered for real. `condition: nil` for the
      # identical reason `lower_process_manager_begin`'s own comment
      # gives (the real gate — an instance must EXIST for this
      # correlation — is an existence check `SagaInterpreter` still owns,
      # not a value comparison). `dispatches: []` — ending fires no
      # command of its own. `persistence: Persistence::Ended` — see that
      # variant's own comment (`../primal_ir.rb`) for why deletion
      # doesn't fit `Checkpointed`/`Ephemeral`; `ReactionExecutor#
      # match_and_checkpoint?` never needs to special-case it, since it
      # only ever acts on `Checkpointed` and otherwise no-ops — the
      # actual deletion stays `SagaInterpreter#end_saga`'s own job,
      # unlike `Checkpointed`, which `ReactionExecutor` DOES perform.
      def lower_process_manager_end(pm)
        PrimalIR::Reaction.new(
          trigger:     PrimalIR::Trigger.new(name: pm.ends_on, qualifier: nil),
          condition:   nil,
          dispatches:  [],
          context:     PrimalIR::Context::Correlated.new(correlation_key: pm.correlation_head, memory: false,
                                                         lifecycle: PrimalIR::Lifecycle::End.new),
          persistence: PrimalIR::Persistence::Ended.new,
          failure:     PrimalIR::Failure::Drop.new
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

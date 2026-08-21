require_relative "../bluebook/expression/evaluator"
require_relative "../bluebook/expression/binding_lowering"
require_relative "saga_interpreter"

module Hecksagain
  module Runtime
    # PRD 12 (ADR 0030 Slice 3, design) — the `Reaction` executable
    # shape, and the two lowering functions that produce it from a real
    # canonical `Policy`/`ProcessManager` leg. Deliberately minimal: this
    # exists to make the provenance-erasure test
    # (`spec/reaction_provenance_spec.rb`) possible against REAL data,
    # not to replace `PolicyInterpreter`/`SagaInterpreter` — neither
    # interpreter reads anything in this file, and nothing here executes
    # a `Reaction`. Building the actual executor (matching/binding/
    # dispatching/checkpointing/compensating a bare `Reaction`, with the
    # two interpreters retired in favour of it) is PRD 12's own named
    # next PRD, not this one.
    module ReactionLowering
      Reaction = Struct.new(:trigger, :condition, :bindings, :dispatches, :context, :persistence, :failure, keyword_init: true)

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

      module Context
        Stateless  = Class.new
        Correlated = Struct.new(:correlation_key, :memory, keyword_init: true)
      end

      module Persistence
        Ephemeral    = Class.new
        Checkpointed = Struct.new(:boundary, keyword_init: true)
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
      # a loaded registry) → a bare `Reaction`. `dispatches` is already
      # the one-element case of the plural field ADR 0029's own step 4
      # would generalize — not attempted here, sketched as already-
      # plural so `evaluate_condition`'s own caller never needs to know
      # which kind of `Reaction` it's holding.
      def lower_policy(policy)
        Reaction.new(
          trigger:     Trigger.new(name: policy.event_name, qualifier: policy.event_qualifier),
          condition:   policy.where.to_s.empty? ? nil : Bluebook::Expression::Evaluator.parse(policy.where),
          bindings:    policy.with_spec.map { |key, value| Bluebook::Expression::BindingLowering.lower([key, value], available_sources: [:payload]) },
          dispatches:  [CommandRef.new(domain: policy.target_domain, command_name: policy.trigger_command)],
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
      # (a compensating leg cannot compensate itself — the guard against
      # infinite recursion is real, not defensive-only, for any process
      # manager whose refused-handler IS its own only handler).
      def lower_process_manager_leg(pm, handler)
        refused_handler = pm.handler_for(SagaInterpreter::REFUSED)
        compensation = refused_handler && !refused_handler.equal?(handler) ? lower_process_manager_leg(pm, refused_handler) : nil

        Reaction.new(
          trigger:     Trigger.new(name: handler.event_type, qualifier: nil),
          condition:   state_equals(handler.from_state),
          bindings:    handler.dispatches.flat_map { |d| d.with_spec.map { |key, value| Bluebook::Expression::BindingLowering.lower([key, value], available_sources: %i[correlation payload memory]) } },
          dispatches:  handler.dispatches.map { |d| CommandRef.new(domain: nil, command_name: d.command_name) },
          context:     Context::Correlated.new(correlation_key: pm.correlates_by, memory: true),
          persistence: Persistence::Checkpointed.new(boundary: :before_dispatch),
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

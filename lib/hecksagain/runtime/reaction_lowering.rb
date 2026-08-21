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
          context:     PrimalIR::Context::Correlated.new(correlation_key: pm.correlation_head, memory: true),
          persistence: PrimalIR::Persistence::Checkpointed.new(boundary: :before_dispatch, to_state: handler.to_state),
          failure:     PrimalIR::Failure::Managed.new(retry: SagaInterpreter::MAX_DEFECT_RETRIES, compensation: compensation)
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

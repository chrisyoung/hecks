require_relative "reaction"
require_relative "reaction_lowering"
require_relative "value"

module Hecksagain
  module Runtime
    # PRD 12's own named next step — the real `Reaction` EXECUTOR:
    # match → evaluate condition → checkpoint (if persistent) → resolve
    # bindings → dispatch → classify outcome → compensate on failure
    # (if managed). One implementation, run identically for a bare
    # `Reaction` regardless of whether `ReactionLowering.lower_policy`
    # or `.lower_process_manager_leg` produced it — the provenance-
    # erasure test's own bar, now against real execution, not just
    # shape.
    #
    # DELIBERATELY NOT WIRED IN to replace `PolicyInterpreter`/
    # `SagaInterpreter` — that swap needs the full corpus/fuzzer parity
    # gate ADR 0029's own step 5 insists on before anything old is
    # deleted, which this pass does not attempt. This class exists to
    # make that comparison possible: `spec/reaction_executor_spec.rb`
    # runs REAL banking/wire scenarios through both the production
    # interpreters AND this executor and asserts identical outcomes.
    # Retiring the two interpreters in this class's favor is real,
    # separate, future work.
    class ReactionExecutor
      def initialize(registry, door:)
        @registry = registry
        @door     = door
      end

      # Runs `reaction` once against `sources` (the same bucket-keyed
      # Hash `BindingLowering.resolve` already reads — `{payload:,
      # correlation:, memory:}`, whichever the reaction's own bindings
      # actually reference) and `state` (an EMPTY Hash for a stateless
      # policy, `{state: instance[:state]}` for a correlated leg —
      # `ReactionLowering.evaluate_condition`'s own two real shapes).
      #
      # `on_checkpoint`, called ONCE with the ADVANCED state (`{state:
      # reaction.persistence.to_state}`, merged over the caller's own
      # `state`), before any dispatch is attempted, only when
      # `reaction.persistence` is `Checkpointed` — the exact boundary
      # `SagaInterpreter#advance_saga` already fixes (state moves, and
      # is persisted, BEFORE its dispatches run) — never called for a
      # `Stateless`/`Ephemeral` policy, which has nothing to checkpoint.
      # The advanced state is also what `condition`/dispatches/
      # compensation see for the REST of this call — a compensating
      # leg's own guard checks against the state `unwind`'s real target
      # already moved to, not the state the triggering leg started in;
      # get this backwards and compensation's own guard never matches,
      # so it silently never fires (found failing outright, not by
      # inspection — see `Persistence::Checkpointed`'s own header).
      # `domain` — the ambient domain a bare command name qualifies
      # against, same fallback both original interpreters already used.
      #
      # Returns `{matched: false}` when the condition doesn't hold (the
      # same "nothing happened, nothing logged" shape `where_holds?`/
      # `advance_saga`'s own guard already give), or `{matched: true,
      # outcomes: [...]}` — one outcome hash per dispatch, each exactly
      # `Reaction.deliver_dispatch`'s own shape.
      #
      # EACH DISPATCH FAILS AND COMPENSATES INDEPENDENTLY — ADR 0030's
      # own "second concrete finding," ported literally:
      # `handler.dispatches.each` in the original `SagaInterpreter` does
      # not stop at the first failure, and a refusal or exhausted defect
      # on ONE dispatch compensates immediately rather than waiting for
      # every dispatch in the reaction to be attempted. This loop does
      # the same — `compensate` runs, if `reaction.failure` is `Managed`,
      # right after the dispatch that failed, before the NEXT dispatch
      # in this same reaction is even attempted.
      # `state` is MUTATED IN PLACE, never reassigned — the same "one
      # shared Hash" contract `SagaInterpreter`'s own `instance` already
      # has. This matters for real, not just as a style choice: two of
      # THIS reaction's own dispatches can independently fail and
      # independently call `compensate`, below — the real system's own
      # idempotency guard against DOUBLE compensation is exactly that
      # the second call's own condition check sees the state the FIRST
      # compensation call already moved (to the compensating leg's own
      # `to_state`), no longer matching the compensating leg's own
      # guard, so it silently no-ops the second time — "the check is
      # the guard," `unwind`'s own real comment, ported literally. A
      # fresh `state.merge(...)` here would hand each independent
      # compensation call its own copy of the PRE-compensation state,
      # and the guard would match a second, WRONG time — found double-
      # crediting a drawer in this file's own differential spec, not by
      # inspection.
      def run(reaction, sources:, state: {}, on_checkpoint: nil, domain: nil)
        attrs = sources[:payload] || {}
        return { matched: false } unless Runtime::ReactionLowering.evaluate_condition(reaction, state, attrs)

        if reaction.persistence.is_a?(Runtime::ReactionLowering::Persistence::Checkpointed)
          state[:state] = reaction.persistence.to_state
          on_checkpoint&.call(state)
        end

        outcomes = reaction.dispatches.map do |dispatch|
          outcome = run_dispatch(dispatch, sources, domain)
          compensate(reaction, sources, state, domain) unless outcome[:delivered]
          outcome
        end

        { matched: true, outcomes: outcomes }
      end

      private

      def run_dispatch(dispatch, sources, domain)
        target = qualify(dispatch.command_ref, domain)
        args   = resolve_args(dispatch, sources)

        Reaction.deliver_dispatch(max_retries: SagaInterpreter::MAX_DEFECT_RETRIES) { @door.reenter(target, **args) }
      end

      def resolve_args(dispatch, sources)
        dispatch.bindings.to_h do |binding|
          destination, resolved = Bluebook::Expression::BindingLowering.resolve(binding, sources)
          [destination, Value.materialize(resolved)]
        end
      end

      # `command_ref.domain`, if the reaction's own dispatch named one
      # (a policy's `target_domain`) — else the ambient ONLY if the
      # command name doesn't already carry one (the same defensive
      # check `SagaInterpreter#qualified` already makes; a real
      # `command_name` never actually contains "::" today — `Naming.
      # command_ref` always rewrites it to a dot — but the check is
      # free and matches existing precedent rather than assuming that
      # holds forever).
      def qualify(command_ref, domain)
        return "#{command_ref.domain}::#{command_ref.command_name}" if command_ref.domain
        return command_ref.command_name if command_ref.command_name.include?("::")

        "#{domain}::#{command_ref.command_name}"
      end

      # A refused or exhausted-defect dispatch compensates by running
      # its OWN reaction's `failure.compensation` — itself a full
      # `Reaction`, run through this SAME `run` method, not a bare
      # dispatch — matching `unwind`'s own real shape (a compensating
      # leg is a whole leg, with its own guard, its own bindings, its
      # own possible further dispatches). A `Drop` failure (a stateless
      # policy) has nothing to compensate; `Managed` with no
      # `compensation` (a process manager with no `on :refused` handler
      # at all — real in the corpus, e.g. `Onboarding`) compensates
      # nothing either, matching `unwind`'s own `return unless handler`
      # guard exactly.
      def compensate(reaction, sources, state, domain)
        return unless reaction.failure.is_a?(Runtime::ReactionLowering::Failure::Managed)
        return unless reaction.failure.compensation

        run(reaction.failure.compensation, sources: sources, state: state, domain: domain)
      end
    end
  end
end

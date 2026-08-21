require_relative "../primal_ir"
require_relative "reaction"
require_relative "reaction_lowering"
require_relative "value"

module Hecksagain
  module Runtime
    # The real `Reaction` EXECUTOR: match → evaluate condition →
    # checkpoint (if persistent), and, separately, resolve bindings →
    # dispatch → classify outcome. One implementation, run identically
    # for a bare `Reaction` regardless of whether `ReactionLowering.
    # lower_policy` or `.lower_process_manager_leg` produced it — the
    # provenance-erasure test's own bar, against real execution.
    #
    # WIRED IN FOR REAL — `PolicyInterpreter#deliver`/`SagaInterpreter#
    # advance_saga`/`#unwind` all call this now instead of their own
    # former hand-rolled dispatch/checkpoint logic.
    #
    # TWO PUBLIC STEPS, DELIBERATELY NOT ONE ATOMIC "run," AND
    # DELIBERATELY REGISTRY/MUTEX-AGNOSTIC — this class does not know
    # `@registry.saga_mutex` exists, on purpose. `SagaInterpreter#
    # advance_saga`'s own comment already named the real constraint
    # before this executor existed: the state-check-and-checkpoint step
    # must be mutex-guarded, but the dispatch cascade that follows must
    # NOT be — `@door.reenter` can recursively re-enter the SAME
    # interpreter on the SAME thread (a leg triggering another saga, or
    # itself again), and `Mutex` is not reentrant, so holding it across
    # a dispatch would deadlock the thread against itself the moment
    # any real chain did that. Compensation makes this sharper still:
    # `unwind` re-acquires the mutex SEPARATELY for its OWN check-and-
    # mutate step, not by holding one lock across the whole leg — so
    # mutex-wrapping is a decision only a caller that KNOWS about the
    # mutex can make correctly, once per step, including for a
    # compensating leg's own step. That caller is `SagaInterpreter`,
    # which is also exactly why compensation ORCHESTRATION ("on
    # failure, advance to the `on :refused` leg") stays hand-written
    # there too, not folded into this class — a stateless `policy` has
    # no compensation concept at all, so it isn't this class's job to
    # assume every `Reaction` has one.
    class ReactionExecutor
      def initialize(registry, door:)
        @registry = registry
        @door     = door
      end

      # STEP ONE — safe to call inside a caller's own mutex, and
      # nothing else in this class is. Evaluates `reaction.condition`
      # against `state` (an EMPTY Hash for a stateless policy, `{state:
      # instance[:state]}` for a correlated leg) and `sources[:payload]`.
      # Returns `false` — nothing else — the moment the condition
      # doesn't hold, the same "nothing happened, nothing logged" shape
      # `where_holds?`/`advance_saga`'s own guard already give.
      #
      # When it matches AND `reaction.persistence` is `Checkpointed`,
      # mutates `state` IN PLACE to the advanced state (`state[:state]
      # = reaction.persistence.to_state`) and calls `on_checkpoint`
      # with it — the exact boundary `SagaInterpreter#advance_saga`
      # already fixed (state moves, and is persisted, BEFORE any
      # dispatch runs). `state` MUST be mutated in place, never
      # reassigned: a compensating leg's own later call to THIS method
      # (`SagaInterpreter`'s own orchestration, on a dispatch's
      # failure) needs to see the state THIS call already moved to, so
      # its own guard can correctly no-op a SECOND compensation attempt
      # rather than matching a second, wrong time — "the check is the
      # guard," `unwind`'s own real comment, ported literally. A fresh
      # copy here would hand a later call the PRE-transition state
      # instead (confirmed via a real double-credited drawer in this
      # class's own differential spec before this was fixed).
      def match_and_checkpoint?(reaction, state:, sources:, on_checkpoint: nil)
        attrs = sources[:payload] || {}
        return false unless Runtime::ReactionLowering.evaluate_condition(reaction, state, attrs)

        if reaction.persistence.is_a?(PrimalIR::Persistence::Checkpointed)
          state[:state] = reaction.persistence.to_state
          on_checkpoint&.call(state)
        end

        true
      end

      # STEP TWO — run OUTSIDE any mutex the caller holds (see this
      # class's own header for why). Resolves bindings and dispatches
      # each of `reaction.dispatches` in turn, through `dispatch_one!`
      # below. Returns one outcome hash per dispatch — never raises,
      # never decides what to do about a failure; that decision belongs
      # to the caller (see this class's own header on why compensation
      # orchestration lives in `SagaInterpreter`, not here).
      def dispatch!(reaction, sources:, domain: nil, correlation: nil, on_defect_attempt: nil, on_exhausted: nil)
        reaction.dispatches.map do |dispatch|
          dispatch_one!(reaction, dispatch, sources: sources, domain: domain, correlation: correlation,
                                            on_defect_attempt: on_defect_attempt, on_exhausted: on_exhausted)
        end
      end

      # ONE dispatch, checked and run — the granularity `SagaInterpreter`
      # itself actually needs: a leg's several dispatches are each
      # logged (`saga_dispatch_log`) and, on failure, each independently
      # trigger compensation (`unwind`) BEFORE the next dispatch in the
      # same leg runs, so the reaction-depth ceiling has to be checked
      # FRESH per dispatch, not once for the whole leg — a real,
      # exercised distinction (`spec/runtime/saga_spec.rb`'s own "unwinds
      # when the reaction-depth ceiling is hit" test counts exactly
      # THREE separate `reaction_depth_reached?` calls across two
      # dispatches in ONE leg plus one in another). `dispatch!` above is
      # this method called once per `reaction.dispatches` entry — the
      # shape `PolicyInterpreter` needs, since a policy's `Reaction`
      # only ever has one.
      #
      # Answers `Reaction.depth_ceiling_record(@door)` directly, without
      # ever calling `Reaction.deliver_dispatch`, when the ceiling is
      # reached — the SAME `{delivered: false, reason:}` shape a refusal
      # gets, so a caller's own outcome-handling code (see
      # `SagaInterpreter#deliver_saga_dispatch`) needs no separate
      # branch for it: the ceiling isn't a domain decision, but it isn't
      # ambiguous either — the leg unambiguously did not run — so it
      # merges and compensates exactly like an ordinary refusal.
      #
      # `on_defect_attempt`/`on_exhausted`, each called as `(dispatch,
      # attempt, error)` — a `Dispatch`, not a bare `(attempt, error)`
      # the way `Reaction.deliver_dispatch`'s own hooks are, since a
      # caller's own warn/log wording needs to name WHICH command this
      # was (`dispatch.command_ref.command_name`) when a reaction fires
      # more than one — every real `SagaInterpreter` warn/log message
      # already did, and this is what lets that wording survive moving
      # the retry loop itself into this shared class.
      #
      # `correlation` — the runtime VALUE a correlated leg's own
      # `reaction.context.correlation_key` names (e.g. `"wire-1"`),
      # threaded through to `@door.reenter` as `saga_correlation:` —
      # `nil` for a stateless policy's `Context::Stateless`, matching
      # `@door.reenter`'s own `saga_correlation: nil` default exactly
      # (PolicyInterpreter never passes `correlation:` at all).
      def dispatch_one!(reaction, dispatch, sources:, domain: nil, correlation: nil, on_defect_attempt: nil, on_exhausted: nil)
        return Reaction.depth_ceiling_record(@door) if Reaction.depth_ceiling_reached?(@door)

        run_dispatch(reaction, dispatch, sources, domain, correlation, on_defect_attempt, on_exhausted)
      end

      # PUBLIC on purpose, unlike the rest of this class's own internals
      # below — `PolicyInterpreter`/`SagaInterpreter` both need to
      # resolve a dispatch's own args BEFORE calling `dispatch!`, to log
      # the raw inputs a dispatch resolved from (`policy_dispatch_log`/
      # `saga_dispatch_log` — Ruby-only bookkeeping `Properties.
      # dispatch_binding_fidelity` independently re-derives against,
      # never itself part of the executable shape, so it stays the
      # caller's own concern rather than folding logging into this
      # class). Resolving twice (once here for the log, once again
      # inside `dispatch!`) is deliberate, not an oversight — a pure,
      # cheap function, and simpler than threading resolved args back
      # out through `dispatch!`'s own outcome shape.
      def resolve_args(dispatch, sources)
        return sources[:payload] || {} if dispatch.bindings == PrimalIR::Dispatch::VERBATIM

        dispatch.bindings.to_h do |binding|
          destination, resolved = Bluebook::Expression::BindingLowering.resolve(binding, sources)
          [destination, Value.materialize(resolved)]
        end
      end

      private

      def run_dispatch(reaction, dispatch, sources, domain, correlation, on_defect_attempt, on_exhausted)
        target = qualify(dispatch.command_ref, domain)
        args   = resolve_args(dispatch, sources)

        Reaction.deliver_dispatch(
          max_retries:       SagaInterpreter::MAX_DEFECT_RETRIES,
          on_defect_attempt: on_defect_attempt && ->(attempt, error) { on_defect_attempt.call(dispatch, attempt, error) },
          on_exhausted:      on_exhausted && ->(attempt, error) { on_exhausted.call(dispatch, attempt, error) }
        ) { @door.reenter(target, saga_correlation: correlation_kwarg(reaction, correlation), **args) }
      end

      # `nil` unless `reaction.context` is `Correlated` — a stateless
      # policy's `Context::Stateless` has no `correlation_key` at all,
      # and `@door.reenter`'s own `saga_correlation: nil` default is
      # exactly what every PolicyInterpreter call already produced
      # before this method existed (it never passed the kwarg). The key
      # is STRINGIFIED — `SagaInterpreter#deliver_saga_dispatch`'s own
      # original stamp always was (`pm.correlation_head.to_s`), matching
      # `Correlation#saga_correlation`'s own read side
      # (`event.correlation[pm.correlation_head.to_s]`) — unlike the
      # SYMBOL-keyed `:correlation` bucket in `sources`, which
      # `BindingLowering`'s own `Reference` lookups expect.
      def correlation_kwarg(reaction, correlation)
        return nil unless reaction.context.is_a?(PrimalIR::Context::Correlated)

        { reaction.context.correlation_key.to_s => correlation }
      end

      # `command_ref.domain`, if the reaction's own dispatch named one
      # (a policy's `target_domain`) — else the ambient ONLY if the
      # command name doesn't already carry one (the same defensive
      # check `SagaInterpreter#qualified` used to make, before this
      # method replaced it for both interpreters; a real `command_name`
      # never actually contains "::" today — `Naming.command_ref`
      # always rewrites it to a dot — but the check is free and matches
      # existing precedent rather than assuming that holds forever).
      def qualify(command_ref, domain)
        return "#{command_ref.domain}::#{command_ref.command_name}" if command_ref.domain
        return command_ref.command_name if command_ref.command_name.include?("::")

        "#{domain}::#{command_ref.command_name}"
      end
    end
  end
end

require "json"
require_relative "saga_interpreter/correlation"
require_relative "../bluebook/process_manager"
require_relative "../bluebook/expression/binding_lowering"
require_relative "errors"
require_relative "value"
require_relative "reaction"
require_relative "reaction_lowering"
require_relative "reaction_executor"

module Hecksagain
  module Runtime
    # ADR 0029/0030's own real convergence, saga's own half —
    # `advance_saga`/`unwind`/`deliver_saga_dispatch` no longer hand-roll
    # their own state-guard/checkpoint/dispatch/refusal/defect/retry/
    # binding-resolution logic; each leg is lowered once
    # (`ReactionLowering.lower_process_manager_leg`) and run through
    # `ReactionExecutor` — the SAME class `PolicyInterpreter` uses for
    # its own reactions now. What's left here is what's genuinely
    # saga-specific: instance lifecycle (`begin_saga`/`end_saga`),
    # correlation lookup, the mutex-reentrancy boundary itself (see
    # `advance_saga`'s own comment), and compensation ORCHESTRATION —
    # "on failure, run the `on :refused` leg" — which stays hand-written
    # because a stateless `policy` has no compensation concept at all
    # for `ReactionExecutor` to assume.
    class SagaInterpreter
      include Correlation

      # The trigger lives on the declaration it triggers, not on the runtime that
      # notices it — see ProcessManager::REFUSED.
      REFUSED = Bluebook::ProcessManager::REFUSED

      # A crash gets this many extra attempts before the procedure gives up
      # and treats it as something to compensate for — see
      # `deliver_saga_dispatch`'s own comment for why a crash isn't unwound
      # on the first failure the way a domain refusal is.
      MAX_DEFECT_RETRIES = 3

      attr_reader :registry

      def initialize(registry, door:)
        @registry = registry
        @door     = door
        @executor = ReactionExecutor.new(registry, door: door)
      end

      def advance(event, domain)
        bluebook = @registry.bluebook(domain)
        return unless bluebook

        bluebook.process_managers.each do |pm|
          begin_saga(pm, event, domain)
          advance_saga(pm, event, domain)
          end_saga(pm, event, domain)
        end
      end

      private

      # THE CHECKPOINT WRITE, shared by every mutation site below —
      # holds `saga_mutex` across BOTH the in-memory Hash mutation and
      # the persistence write (§7), not just the Hash mutation alone:
      # two threads racing the SAME (process_manager, correlation) key
      # could otherwise interleave their writes out of order, silently
      # reordering a saga's own transition history — worse for the
      # adapters with no locking of their own (Heki) than for Postgres.
      # `deep_copy` guards against the exact shape of bug PR #175 itself
      # already found once (over-freezing a live, still-mutated Hash) —
      # never hand a persistence adapter the SAME object `advance_saga`/
      # `unwind` go on to mutate in place; round-tripping through JSON
      # is also what guarantees the value is safe for every adapter that
      # itself calls `JSON.generate` on it.
      def checkpoint(pm, correlation, instance, domain)
        @registry.saga_persistence(domain).save_saga(
          process_manager: pm.name, correlation: correlation,
          state: instance[:state], memory: deep_copy(instance[:memory])
        )
      end

      def deep_copy(hash) = JSON.parse(JSON.generate(hash), symbolize_names: true)

      # `Lifecycle::Begin` (`ReactionLowering.lower_process_manager_begin`,
      # see its own comment) — the trigger and initial state are read off
      # the lowered `reaction` now, not `pm.starts_on`/`pm.states.first`
      # directly. What stays hand-written, on purpose: the EXISTENCE gate
      # itself (`@registry.saga_instances[pm.name].key?(correlation)`) —
      # `Reaction` cannot know the owning process manager's own NAME, only
      # a correlation FIELD name, so this registry-shaped check has
      # nowhere else to live. `@executor.match_and_checkpoint?` still does
      # the real work of writing `instance[:state]` and calling
      # `on_checkpoint` — `reaction.condition` is `nil` (unconditionally
      # true), so this only ever WRITES here, never refuses.
      def begin_saga(pm, event, domain)
        reaction = ReactionLowering.lower_process_manager_begin(pm)
        return unless event.name == reaction.trigger.name

        correlation = saga_correlation(pm, event)
        if correlation.to_s.empty?
          @registry.saga_log << { process_manager: pm.name, on: event.name,
                                  born: false, reason: "no #{pm.correlates_by} in the payload" }
          return
        end

        created = @registry.saga_mutex.synchronize do
          next false if @registry.saga_instances[pm.name].key?(correlation)

          instance = { memory: event.payload }
          @executor.match_and_checkpoint?(reaction, state: instance, sources: { payload: event.payload },
                                          on_checkpoint: ->(_state) { checkpoint(pm, correlation, instance, domain) })
          @registry.saga_instances[pm.name][correlation] = instance
          true
        end
        return unless created

        @registry.saga_log << { process_manager: pm.name, on: event.name,
                                instance: correlation, born: true, state: reaction.persistence.to_state }
      end

      # THE MUTEX COVERS ONLY THE STATE-CHECK-AND-MUTATE-AND-CHECKPOINT
      # STEP (`ReactionExecutor#match_and_checkpoint?`, called from
      # inside this very block), never the dispatch cascade that
      # follows — `deliver_leg_dispatches` calls `@door.reenter`, which
      # can recursively re-enter THIS SAME interpreter (a saga's own leg
      # triggering another saga, or itself again) on the SAME thread,
      # and `Mutex` is not reentrant: holding it across that call would
      # deadlock the thread against itself the moment any real chain did
      # that.
      def advance_saga(pm, event, domain)
        handler = pm.handler_for(event.name)
        return unless handler

        correlation = saga_correlation(pm, event)
        return if correlation.to_s.empty?

        record   = { process_manager: pm.name, on: event.name, instance: correlation }
        reaction = ReactionLowering.lower_process_manager_leg(pm, handler)
        instance = nil

        advanced = @registry.saga_mutex.synchronize do
          instance = @registry.saga_instances[pm.name][correlation]
          unless instance
            @registry.saga_log << record.merge(advanced: false, reason: "no conversation remembers #{correlation.inspect}")
            next false
          end

          matched = @executor.match_and_checkpoint?(
            reaction, state: instance, sources: leg_sources(pm, event, instance, correlation),
            on_checkpoint: ->(_state) { checkpoint(pm, correlation, instance, domain) }
          )
          unless matched
            @registry.saga_log << record.merge(advanced: false,
                                               reason:   "in #{instance[:state].inspect}, not #{handler.from_state.inspect}")
            next false
          end

          true
        end
        return unless advanced

        @registry.saga_log << record.merge(advanced: true, from: handler.from_state, to: handler.to_state)

        deliver_leg_dispatches(pm, handler, reaction, event, instance, correlation, domain)
      end

      # THE SOURCES a leg's own bindings resolve against — correlation
      # head, event payload, accumulated memory, the same three buckets
      # `BindingLowering`'s own priority chain expects
      # (`available_sources: %i[correlation payload memory]`, ADR 0030
      # Slice 2). Built ONCE per leg, not once per dispatch — nothing in
      # `advance_saga`/`unwind`/`deliver_leg_dispatches` mutates
      # `instance[:memory]` or `event.payload` between one dispatch and
      # the next within the same leg, so a fresh Hash per dispatch would
      # be redundant, not more correct.
      def leg_sources(pm, event, instance, correlation)
        { correlation: { pm.correlation_head => correlation }, payload: event.payload, memory: instance[:memory] }
      end

      # ONE Reaction's worth of dispatches, each run and logged
      # independently — a leg's second dispatch still runs even when its
      # first one failed (ADR 0030's own "second concrete finding"), and
      # each failure gets its OWN compensation attempt via `unwind`
      # (safe to call more than once per leg: `unwind`'s own from-state
      # guard makes a second call a no-op). `handler.dispatches.zip(
      # reaction.dispatches)` — same order, same count, by construction
      # of `ReactionLowering.lower_process_manager_leg` — pairs each
      # CANONICAL dispatch spec (`with_spec`/`command_name`, for
      # `saga_dispatch_log`'s own raw-input bookkeeping) with its
      # LOWERED counterpart (`bindings`, for `ReactionExecutor`).
      def deliver_leg_dispatches(pm, handler, reaction, event, instance, correlation, domain)
        sources = leg_sources(pm, event, instance, correlation)

        handler.dispatches.zip(reaction.dispatches).each do |spec, dispatch|
          deliver_saga_dispatch(pm, reaction, spec, dispatch, sources, event, instance, correlation, domain)
        end
      end

      # ADR 0029's own step 2 — the refusal/defect rescue, the depth-
      # ceiling check, and argument resolution are `ReactionExecutor`/
      # `Reaction.deliver_dispatch`'s own now, shared with
      # `PolicyInterpreter#deliver`; what's genuinely specific to a
      # process-manager leg, and stays here rather than moving into
      # either of those, is compensation itself: a refused leg UNWINDS
      # (fires the `on :refused` handler, moving state to its `to_state`
      # BEFORE its own dispatches run, so a second refusal finds the
      # instance already past `from_state` instead of looping), and so
      # does a leg whose crash outlives every retry or that hits the
      # reaction-depth ceiling — tagged `defect_compensated: true`
      # rather than folded into an ordinary refusal's shape, so the log
      # never misrepresents a crash as a decision the domain made. A
      # ceiling hit and an ordinary refusal/exhausted-defect share the
      # SAME merge below because `ReactionExecutor#dispatch_one!`
      # answers the ceiling-reached case in the identical
      # `{delivered: false, reason:}` shape `Reaction.deliver_dispatch`
      # itself would for a refusal — no separate branch needed.
      #
      # `on_defect_attempt` is this leg's own running history: every
      # RETRYABLE attempt gets its own intermediate `saga_log` entry
      # (`retrying: true`) — `PolicyInterpreter` has nowhere to put one,
      # a saga's own `saga_log` always did.
      def deliver_saga_dispatch(pm, reaction, spec, dispatch, sources, event, instance, correlation, domain)
        record = { process_manager: pm.name, instance: correlation, dispatch: spec.command_name }

        # THE RAW INPUTS this dispatch resolves from, captured alongside
        # the result — never re-derived from history[:saga_instances]
        # later (that only ever holds the FINAL memory, after every step
        # has run; this dispatch's own memory, at the moment it actually
        # fired, is a different fact for a saga whose memory keeps
        # changing). `spec.with_spec.empty?` skipped: nothing declared
        # to check, a tautological pass, the same reason a command with
        # no givens/from is skipped by lifecycle_guard_and_given_
        # violations_are_refused. Resolved via `ReactionExecutor` — the
        # same shared, cheap, pure function `PolicyInterpreter#
        # log_policy_dispatch` calls a second time for its own log,
        # resolved again inside `dispatch_one!` rather than threaded
        # back out through its own outcome shape.
        unless spec.with_spec.to_a.empty?
          args = @executor.resolve_args(dispatch, sources)
          @registry.saga_dispatch_log << { process_manager: pm.name, instance: correlation, dispatch: spec.command_name,
                                            on: event.name, correlation_head: pm.correlation_head,
                                            event_payload: event.payload, memory: Value.materialize(instance[:memory]),
                                            with_spec: spec.with_spec, args: args }
        end

        outcome = @executor.dispatch_one!(
          reaction, dispatch, sources: sources, domain: domain, correlation: correlation,
          on_defect_attempt: lambda { |_dispatch, attempt, error|
            @registry.saga_log << record.merge(delivered: false, reason: error.message,
                                               defect: true, error_class: error.class.name,
                                               attempt: attempt, retrying: true)
          },
          on_exhausted: lambda { |_dispatch, attempt, error|
            warn "[hecksagain] defect in saga #{pm.name} — instance #{correlation.inspect} " \
                 "dispatching #{spec.command_name} after #{attempt} attempts: #{error.class}: #{error.message}"
          }
        )

        if outcome[:delivered]
          @registry.saga_log << record.merge(outcome)
          return
        end

        # A refusal, an exhausted defect, or a reaction-depth ceiling
        # hit all UNWIND — see this method's own header for why a crash
        # is tagged `defect_compensated: true` rather than left looking
        # like an ordinary refusal (a ceiling hit carries no `:defect`
        # key at all, so it falls through to the plain `outcome` merge
        # unchanged, same as a domain refusal).
        @registry.saga_log << record.merge(outcome[:defect] ? outcome.merge(defect_compensated: true) : outcome)
        unwind(pm, event, instance, correlation, domain)
      end

      # A refused leg UNWINDS — the procedure runs the leg declared `on :refused`,
      # which is where the compensation lives. So does a leg that hit the
      # reaction-depth ceiling, and so does a leg that crashed and stayed
      # crashing through MAX_DEFECT_RETRIES — see `deliver_saga_dispatch`'s own
      # comments for why each of those is safe to route here.
      #
      # Until this existed a refusal was RECORDED and nothing else happened. The
      # wire's thousand was taken from the source, refused by the destination, and
      # sat nowhere until a human dispatched the reversal by hand ; banking's
      # settlement left a debit standing with no credit and no reversal at all.
      # Both bluebooks had written the compensating leg. Nothing armed it.
      #
      # A compensation that is itself refused does NOT unwind again, and needs no
      # flag to stop it: the state moves to the compensating leg's to_state BEFORE
      # its dispatches run, so a second refusal finds the instance no longer in
      # from_state and records that instead. The check is the guard.
      #
      # Self-contained, not fed `reaction.failure.compensation` from the
      # triggering leg above — re-lowers the SAME `on :refused` handler
      # fresh, the same cheap, pure, side-effect-free call
      # `ReactionExecutor#resolve_args`'s own "resolving twice is
      # deliberate" precedent already established; a compensating leg's
      # own `from_state`/`to_state` come from the CANONICAL `handler`
      # here (for this method's own log wording), not from an AST this
      # method would otherwise have to walk back apart.
      def unwind(pm, event, instance, correlation, domain)
        handler = pm.handler_for(REFUSED)
        return unless handler && instance

        record   = { process_manager: pm.name, on: REFUSED, instance: correlation }
        reaction = ReactionLowering.lower_process_manager_leg(pm, handler)

        # Same non-reentrancy reasoning as `advance_saga`'s own comment —
        # the mutex covers only the check-and-mutate-and-checkpoint step.
        advanced = @registry.saga_mutex.synchronize do
          matched = @executor.match_and_checkpoint?(
            reaction, state: instance, sources: leg_sources(pm, event, instance, correlation),
            on_checkpoint: ->(_state) { checkpoint(pm, correlation, instance, domain) }
          )
          unless matched
            @registry.saga_log << record.merge(advanced: false,
                                               reason:   "in #{instance[:state].inspect}, not #{handler.from_state.inspect}")
            next false
          end

          true
        end
        return unless advanced

        @registry.saga_log << record.merge(advanced: true, from: handler.from_state, to: handler.to_state)

        deliver_leg_dispatches(pm, handler, reaction, event, instance, correlation, domain)
      end

      # `Lifecycle::End` (`ReactionLowering.lower_process_manager_end`,
      # see its own comment) — the trigger is read off the lowered
      # `reaction` now, not `pm.ends_on` directly. `pm.ends_on` is
      # itself optional (a procedure need not declare an ending) —
      # `reaction.trigger.name` is `nil` in that case too, and `event.
      # name == nil` is never true, the identical no-op the original
      # `event.name == pm.ends_on` comparison already gave. What stays
      # hand-written: the deletion itself — `Persistence::Ended` has no
      # `ReactionExecutor`-performed effect (see that variant's own
      # comment), so there is nothing to route through
      # `match_and_checkpoint?` here at all, unlike `begin_saga`.
      def end_saga(pm, event, domain)
        reaction = ReactionLowering.lower_process_manager_end(pm)
        return unless event.name == reaction.trigger.name

        correlation = saga_correlation(pm, event)
        return if correlation.to_s.empty?

        ended = @registry.saga_mutex.synchronize do
          next false unless @registry.saga_instances[pm.name].delete(correlation)

          @registry.saga_persistence(domain).delete_saga(process_manager: pm.name, correlation: correlation)
          true
        end
        return unless ended

        @registry.saga_log << { process_manager: pm.name, on: event.name,
                                instance: correlation, ended: true }
      end
    end
  end
end

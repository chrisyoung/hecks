require "json"
require_relative "saga_interpreter/correlation"
require_relative "../bluebook/process_manager"
require_relative "errors"
require_relative "value"
require_relative "reaction"
require_relative "binding"

module Hecksagain
  module Runtime
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

      def begin_saga(pm, event, domain)
        return unless event.name == pm.starts_on

        correlation = saga_correlation(pm, event)
        if correlation.to_s.empty?
          @registry.saga_log << { process_manager: pm.name, on: event.name,
                                  born: false, reason: "no #{pm.correlates_by} in the payload" }
          return
        end

        created = @registry.saga_mutex.synchronize do
          next false if @registry.saga_instances[pm.name].key?(correlation)

          instance = { state: pm.states.first, memory: event.payload }
          @registry.saga_instances[pm.name][correlation] = instance
          checkpoint(pm, correlation, instance, domain)
          true
        end
        return unless created

        @registry.saga_log << { process_manager: pm.name, on: event.name,
                                instance: correlation, born: true, state: pm.states.first }
      end

      # THE MUTEX COVERS ONLY THE STATE-CHECK-AND-MUTATE-AND-CHECKPOINT
      # STEP, never the dispatch cascade that follows — `deliver_saga_
      # dispatch` calls `@door.reenter`, which can recursively re-enter
      # THIS SAME interpreter (a saga's own leg triggering another saga,
      # or itself again) on the SAME thread, and `Mutex` is not
      # reentrant: holding it across that call would deadlock the
      # thread against itself the moment any real chain did that.
      def advance_saga(pm, event, domain)
        handler = pm.handler_for(event.name)
        return unless handler

        correlation = saga_correlation(pm, event)
        return if correlation.to_s.empty?

        record   = { process_manager: pm.name, on: event.name, instance: correlation }
        instance = nil

        advanced = @registry.saga_mutex.synchronize do
          instance = @registry.saga_instances[pm.name][correlation]
          unless instance
            @registry.saga_log << record.merge(advanced: false, reason: "no conversation remembers #{correlation.inspect}")
            next false
          end
          unless instance[:state] == handler.from_state
            @registry.saga_log << record.merge(advanced: false,
                                               reason:   "in #{instance[:state].inspect}, not #{handler.from_state.inspect}")
            next false
          end

          instance[:state] = handler.to_state
          checkpoint(pm, correlation, instance, domain)
          true
        end
        return unless advanced

        @registry.saga_log << record.merge(advanced: true, from: handler.from_state, to: handler.to_state)

        handler.dispatches.each do |spec|
          deliver_saga_dispatch(pm, spec, event, instance, correlation, domain)
        end
      end

      # ADR 0029's own step 2 — the refusal/defect rescue and depth-
      # ceiling check are `Reaction.deliver_dispatch`'s own now, shared
      # with `PolicyInterpreter#deliver`; what's genuinely specific to
      # a process-manager leg, and stays here rather than moving into
      # that shared module, is compensation itself: a refused leg
      # UNWINDS (fires the `on :refused` handler, moving state to its
      # `to_state` BEFORE its own dispatches run, so a second refusal
      # finds the instance already past `from_state` instead of
      # looping), and so does a leg whose crash outlives every retry —
      # tagged `defect_compensated: true` rather than folded into an
      # ordinary refusal's shape, so the log never misrepresents a
      # crash as a decision the domain made. `on_defect_attempt` is
      # this leg's own running history: every RETRYABLE attempt gets
      # its own intermediate `saga_log` entry (`retrying: true`) —
      # `PolicyInterpreter` has nowhere to put one, a saga's own
      # `saga_log` always did.
      def deliver_saga_dispatch(pm, spec, event, instance, correlation, domain)
        args   = dispatch_args(pm, spec, event, instance, correlation)
        record = { process_manager: pm.name, instance: correlation, dispatch: spec.command_name }

        # THE RAW INPUTS `args` WAS RESOLVED FROM, captured alongside the
        # result — never re-derived from history[:saga_instances] later
        # (that only ever holds the FINAL memory, after every step has
        # run; this dispatch's own memory, at the moment it actually
        # fired, is a different fact for a saga whose memory keeps
        # changing). `spec.with_spec.empty?` skipped: nothing declared
        # to check, a tautological pass, the same reason a command with
        # no givens/from is skipped by lifecycle_guard_and_given_
        # violations_are_refused.
        unless spec.with_spec.to_a.empty?
          @registry.saga_dispatch_log << { process_manager: pm.name, instance: correlation, dispatch: spec.command_name,
                                            on: event.name, correlation_head: pm.correlation_head,
                                            event_payload: event.payload, memory: Value.materialize(instance[:memory]),
                                            with_spec: spec.with_spec, args: args }
        end

        # THE CEILING IS NOT A DOMAIN DECISION EITHER — same reasoning as a
        # crash, below — but unlike a crash there is nothing ambiguous
        # about it: the leg unambiguously did not run, so it unwinds
        # exactly like a refusal instead of stranding the instance for a
        # human to notice. `unwind`'s own state guard (it moves to its
        # `to_state` before its dispatches run) is what keeps this from
        # looping if the ceiling is still in effect when the compensating
        # leg tries to dispatch — that leg's own attempt hits this same
        # branch, calls `unwind` again, and finds the instance already
        # past `from_state`.
        if Reaction.depth_ceiling_reached?(@door)
          @registry.saga_log << record.merge(Reaction.depth_ceiling_record(@door))
          unwind(pm, event, instance, correlation, domain)
          return
        end

        outcome = Reaction.deliver_dispatch(
          max_retries:       MAX_DEFECT_RETRIES,
          on_defect_attempt: lambda { |attempt, error|
            @registry.saga_log << record.merge(delivered: false, reason: error.message,
                                               defect: true, error_class: error.class.name,
                                               attempt: attempt, retrying: true)
          },
          on_exhausted:      lambda { |attempt, error|
            warn "[hecksagain] defect in saga #{pm.name} — instance #{correlation.inspect} " \
                 "dispatching #{spec.command_name} after #{attempt} attempts: #{error.class}: #{error.message}"
          }
        ) { @door.reenter(qualified(spec.command_name, domain), saga_correlation: { pm.correlation_head.to_s => correlation }, **args) }

        if outcome[:delivered]
          @registry.saga_log << record.merge(outcome)
          return
        end

        # A refusal or an exhausted defect both UNWIND — see this
        # method's own header for why a crash is tagged
        # `defect_compensated: true` rather than left looking like an
        # ordinary refusal.
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
      def unwind(pm, event, instance, correlation, domain)
        handler = pm.handler_for(REFUSED)
        return unless handler && instance

        record = { process_manager: pm.name, on: REFUSED, instance: correlation }

        # Same non-reentrancy reasoning as `advance_saga`'s own comment —
        # the mutex covers only the check-and-mutate-and-checkpoint step.
        advanced = @registry.saga_mutex.synchronize do
          unless instance[:state] == handler.from_state
            @registry.saga_log << record.merge(advanced: false,
                                               reason:   "in #{instance[:state].inspect}, not #{handler.from_state.inspect}")
            next false
          end

          instance[:state] = handler.to_state
          checkpoint(pm, correlation, instance, domain)
          true
        end
        return unless advanced

        @registry.saga_log << record.merge(advanced: true, from: handler.from_state, to: handler.to_state)

        handler.dispatches.each do |spec|
          deliver_saga_dispatch(pm, spec, event, instance, correlation, domain)
        end
      end

      # ADR 0029's own step 3 — the argument-resolution logic itself is
      # `Binding.resolve`'s now, shared with `PolicyInterpreter#trigger_args`;
      # a saga's own source chain is the full one that module supports —
      # correlation head, then payload, then accumulated memory, in
      # exactly the priority order this method always checked them in.
      # `Binding::NOT_FOUND`, not `nil`, is what a source answers to
      # defer to the next one — `event.payload.key?(value)` (not merely
      # "payload[value] is truthy") is the ORIGINAL check this ports:
      # a payload field present with an explicit `nil` value must still
      # win over memory, not fall through to it.
      def dispatch_args(pm, spec, event, instance, correlation)
        sources = [
          ->(name) { name == pm.correlation_head ? correlation : Binding::NOT_FOUND },
          ->(name) { event.payload.key?(name) ? event.payload[name] : Binding::NOT_FOUND },
          ->(name) { instance[:memory][name] }
        ]
        Binding.resolve(spec.with_spec, sources)
      end

      def qualified(command_name, domain)
        command_name.include?("::") ? command_name : "#{domain}::#{command_name}"
      end

      def end_saga(pm, event, domain)
        return unless event.name == pm.ends_on

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

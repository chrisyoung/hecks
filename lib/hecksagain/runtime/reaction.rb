require_relative "errors"

module Hecksagain
  module Runtime
    # ADR 0029's own step 2 — the refusal/defect rescue shape and the
    # reaction-depth ceiling check, previously spelled out twice
    # (`PolicyInterpreter#deliver`/`#deliver_for_each_row`,
    # `SagaInterpreter#deliver_saga_dispatch`), byte-for-byte identical
    # reasoning both places: a `DOMAIN_REFUSALS` is a recorded, non-fatal
    # outcome (the target refused — a fact about the domain, not this
    # reaction); a `StandardError` is a DEFECT, retried up to
    # `max_retries` times before being recorded, distinguishably
    # (`defect: true`), and never re-raised — see either interpreter's
    # own git history for the full "why catching this here is safe"
    # argument (the triggering command already succeeded and persisted
    # by the time a reaction runs, so letting a defect propagate would
    # only blow up an unrelated caller for a failure it never asked to
    # run).
    #
    # This is the one implementation both interpreters now call. What is
    # NOT extracted here, deliberately: compensation (`unwind`) is real
    # behaviour that differs between a stateless `policy` (none) and a
    # `process_manager` leg (unwinds on both a refusal and an exhausted
    # defect) — this module only ever answers what happened, never what
    # to do about it; the caller decides that, same as it always did.
    module Reaction
      module_function

      # `door.reaction_depth_reached?` — the same guard written twice
      # (`policy_interpreter.rb`, `saga_interpreter.rb`): the door's own
      # ceiling is not a domain decision, so it's checked before ANY
      # dispatch attempt and answers the same `delivered: false` shape a
      # refusal would, before a defect ever gets the chance to look like
      # one.
      def depth_ceiling_reached?(door) = door.reaction_depth_reached?

      def depth_ceiling_record(door)
        { delivered: false, reason: "reaction depth #{door.max_reaction_depth} reached" }
      end

      # THE RESCUE/RETRY SHAPE ITSELF. Yields (a caller-supplied block
      # that performs the actual `@door.reenter` call); never raises —
      # every outcome comes back as a hash to `.merge` into the
      # caller's own record, the same shape both interpreters already
      # built by hand:
      #
      #   {delivered: true}
      #   {delivered: false, reason:}                              (a refusal)
      #   {delivered: false, reason:, defect: true, error_class:}  (a defect, retries exhausted)
      #
      # No attempt COUNT in the final hash — neither original method
      # carried one on its own final record either; a caller that wants
      # one gets it from `on_exhausted`'s own argument, below.
      #
      # `on_defect_attempt`, called once per RETRYABLE failed attempt
      # (never the final, exhausted one — that's `on_exhausted`) —
      # `SagaInterpreter` passes a block that appends an intermediate
      # `saga_log` entry (`retrying: true`), matching its own running
      # history; `PolicyInterpreter` passes nothing, since a policy's
      # own `reaction_log` holds exactly one entry per reaction and has
      # nowhere to put an intermediate one.
      #
      # `on_exhausted`, called exactly once, only once retries run out —
      # both interpreters warn to STDERR here, each with its own
      # differently-worded message (which reaction, which target, which
      # correlation — information this module deliberately doesn't
      # know), which is why the attempt count is handed to the callback
      # rather than folded into the returned hash.
      #
      # Neither interpreter's own observable shape changes by this
      # extraction — this is the existing logic, moved, not new
      # behaviour.
      def deliver_dispatch(max_retries:, on_defect_attempt: nil, on_exhausted: nil)
        attempt = 0
        begin
          yield
          { delivered: true }
        rescue *DOMAIN_REFUSALS => error
          { delivered: false, reason: error.message }
        rescue StandardError => error
          attempt += 1
          if attempt <= max_retries
            on_defect_attempt&.call(attempt, error)
            retry
          end

          on_exhausted&.call(attempt, error)
          { delivered: false, reason: error.message, defect: true, error_class: error.class.name }
        end
      end
    end
  end
end

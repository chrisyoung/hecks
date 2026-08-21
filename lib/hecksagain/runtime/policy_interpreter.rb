require_relative "../naming"
require_relative "errors"
require_relative "query_interpreter"
require_relative "refusal_wording"
require_relative "value"
require_relative "../bluebook/expression/evaluator"
require_relative "saga_interpreter"
require_relative "reaction"
require_relative "binding"

module Hecksagain
  module Runtime
    class PolicyInterpreter
      # A crash gets this many extra attempts before a reaction gives up —
      # the exact constant, and the exact reasoning, `SagaInterpreter`'s
      # own `MAX_DEFECT_RETRIES` already uses: "gives a transient failure
      # (a DB timeout, a race, a cold start) a chance to clear on its own,
      # retrying the identical dispatch, before this is treated as
      # something to compensate for." A stateless policy has nothing to
      # compensate — it never did, and still doesn't — but the transient-
      # failure reasoning names nothing specific to correlation or memory,
      # so it applies here unchanged (ADR 0029's own recorded "Open" item,
      # closed).
      MAX_DEFECT_RETRIES = SagaInterpreter::MAX_DEFECT_RETRIES

      attr_reader :registry

      def initialize(registry, door:)
        @registry = registry
        @door     = door
      end

      # `deliver` returns `nil` for a policy whose `where` did not hold —
      # SILENTLY, the same as a policy `policies_for` never selected at all
      # (an `event_qualifier` miss carries no reaction_log entry either) —
      # so nothing is appended for it. A `for_each` policy answers an ARRAY
      # (one record per matched row) rather than one record ; `Array(...)`
      # is wrong here (it would explode a plain record Hash into its own
      # key/value pairs), so the two shapes are told apart explicitly.
      def react(event, domain)
        policies_for(event).each do |policy, home_domain|
          result = deliver(policy, event, home_domain)
          next if result.nil?

          (result.is_a?(Array) ? result : [result]).each { |record| @registry.reaction_log << record }
        end
      end

      private

      # SCANS EVERY LOADED BLUEBOOK, not just the emitting command's own —
      # a policy commonly lives in the CONSUMER's bluebook, reacting
      # passively to an event a different domain's aggregate emits (the
      # corpus-standard shape : `world/conception/bluebook/domain_cell.bluebook`'s
      # ConceiveOnAbsorption reacts `on "DomainAbsorbed"`, an event
      # `body/organs/bluebook/gut.bluebook`'s Gut.Absorb emits — two
      # different bluebooks, joined only by the event's NAME). Restricting
      # the scan to the emitting domain's own bluebook (the previous
      # shape) silently drops every cross-domain reaction : the policy is
      # never even a candidate, no refusal, no log entry, nothing —
      # confirmed against the corpus's own .behaviors fixtures, several of
      # which encode this exact cross-bluebook cascade as their contract.
      #
      # Returns [policy, home_domain] pairs rather than bare policies —
      # `deliver`/`deliver_for_each` fall back to the REACTING policy's
      # OWN domain (not the emitting one) when a trigger or for_each route
      # is bare, and that fallback has to travel with each match now that
      # a single event can surface policies from several different homes.
      def policies_for(event)
        emitting = Naming.demodulise(event.aggregate)

        @registry.bluebooks.each_value.flat_map do |bluebook|
          matching = bluebook.policies.select do |policy|
            policy.event_name == event.name &&
              (policy.event_qualifier.nil? || policy.event_qualifier == emitting)
          end
          matching.map { |policy| [policy, bluebook.name] }
        end
      end

      # THE GUARD, evaluated against the triggering event's own payload —
      # a policy has no aggregate instance of its own to read state from,
      # so `state` is empty and every bare name a `where` resolves comes
      # from `attrs` (Expression::Resolver#fetch checks `attrs` before
      # `state`, so this is exactly the shape `enforce_givens` already
      # gives a command's own given, minus the settled-record half a
      # policy simply has none of). Called from inside `deliver`'s own
      # rescue-guarded body (both callers, below) — never guarded here —
      # so an EvaluationError (an unresolvable field, a bad comparison) is
      # caught the SAME way any other reaction defect is, not swallowed as
      # though the policy had merely declined to fire.
      def where_holds?(policy, event)
        return true if policy.where.to_s.empty?

        Bluebook::Expression::Evaluator.call(policy.where, {}, event.payload.transform_keys(&:to_sym))
      end

      # ADR 0029's own step 2 — the refusal/defect rescue and depth-
      # ceiling check are `Reaction.deliver_dispatch`'s own now, shared
      # with `SagaInterpreter#deliver_saga_dispatch`; the reasoning for
      # WHY catching a defect here is safe (the command that emitted
      # `event` already succeeded and persisted, so letting a crash
      # propagate would only blow up an unrelated caller for a failure
      # it never asked to run), why a refusal and a defect are told
      # apart, and why a defect retries before being recorded, all
      # lives on `Reaction.deliver_dispatch`'s own comment now — this
      # method's own job shrank to what's genuinely specific to a
      # stateless policy: no intermediate retry log entry (a policy's
      # `reaction_log` holds exactly one entry per reaction, unlike a
      # saga's running `saga_log`), and no compensation to run.
      def deliver(policy, event, domain)
        # `record` ASSIGNED BEFORE ANY BRANCH THAT CAN RAISE, same reason
        # `deliver_for_each`'s own header gives : both rescue clauses below
        # call `.merge` on it, and a defect raised before it existed would
        # be caught here only to raise a second, different NoMethodError
        # trying to record the first one.
        target = "#{policy.target_domain || domain}::#{policy.trigger_command}"
        record = { policy: policy.name, on: event.name, trigger: target }

        return deliver_for_each(policy, event, domain, target, record) unless policy.for_each.to_s.empty?
        return nil unless where_holds?(policy, event)

        return record.merge(Reaction.depth_ceiling_record(@door)) if Reaction.depth_ceiling_reached?(@door)

        outcome = Reaction.deliver_dispatch(max_retries:  MAX_DEFECT_RETRIES,
                                            on_exhausted: lambda { |attempt, error|
                                              warn "[hecksagain] defect in reaction — policy #{policy.name} on #{event.name} " \
                                                   "firing #{target} after #{attempt} attempts: #{error.class}: #{error.message}"
                                            }) { @door.reenter(target, **trigger_args(policy, event)) }

        record.merge(outcome)
      end

      # THE FAN-OUT — `policy.for_each` names a query ; this runs it
      # against the triggering event's own payload (the same source
      # `deliver`'s own ordinary path forwards to `trigger` wholesale) and
      # fires `trigger` once per row, merging each row's own id into the
      # forwarded payload under whichever key THE TARGET COMMAND ITSELF
      # expects to be addressed by (`Behaviour::Command#addressing_key_for`
      # — never a guessed, one-size mint: `Account.Freeze`, addressed by
      # `account` because it is declared ON Account and self-references
      # it, refused every dispatch for as long as this hardcoded
      # `<aggregate>_id` instead — a real bug, found wiring `for_each`
      # into a real domain for the first time, not a hypothetical). A
      # refusal is recorded per row and the fan-out continues ; a crash
      # resolving the QUERY ITSELF, or the TARGET COMMAND'S OWN inability
      # to address this aggregate at all (`addressing_key_for` answering
      # `nil` — a domain-authoring mistake, not a data problem), is a
      # single top-level defect for the policy, the same shape `deliver`'s
      # own outer rescue already gives every other reaction.
      def deliver_for_each(policy, event, domain, target, record)
        return nil unless where_holds?(policy, event)

        query_domain, aggregate_name, query_name = policy.for_each_route(domain)
        aggregate = resolve_query_aggregate(query_domain, aggregate_name, policy.for_each)
        # THE QUERY READS THE EVENT, never the projection — `with:` says
        # what the TRIGGER is given, and the fan-out's query is asking a
        # different question (WHICH rows) in the event's own vocabulary.
        query_args    = event.payload.transform_keys(&:to_sym)
        rows          = QueryInterpreter.new(@registry).call(query_domain, aggregate, query_name, query_args)
        reference_key = addressing_key_for(target, aggregate_name)

        Array(rows).map do |row|
          deliver_for_each_row(target, record, trigger_args(policy, event, reference_key => row[:id]), row)
        end
      rescue *DOMAIN_REFUSALS => error
        record.merge(delivered: false, reason: error.message)
      rescue StandardError => error
        warn "[hecksagain] defect in reaction — policy #{policy.name} on #{event.name} " \
             "resolving for_each #{policy.for_each}: #{error.class}: #{error.message}"
        record.merge(delivered: false, reason: error.message, defect: true, error_class: error.class.name)
      end

      # WHAT THE TRIGGER IS GIVEN. Undeclared, the event's whole payload
      # forwards verbatim — the behaviour every policy had before `with:`
      # existed, and still the right default for a trigger shaped like
      # its event.
      #
      # Declared, it is the same reading a saga's own `dispatch ...,
      # with:` gets (`SagaInterpreter#dispatch_args`): a Symbol names a
      # field on the SOURCE below, anything else is a literal the policy
      # supplies itself. A saga additionally resolves against its own
      # memory and correlation key; a policy has neither — it holds
      # nothing between events — so the source is the event, plus:
      #
      # `extra` is a FAN-OUT'S ROW KEY, merged into the source BEFORE the
      # projection rather than after it. That is what lets a `for_each`
      # policy name the row it is acting on — `with: { account: :account }`
      # — and therefore what lets one send the row and NOTHING ELSE. A
      # trigger needing only which record to act on is the ordinary case
      # for a fan-out, and before this it could not be written: the whole
      # event rode along, and the target had to declare every field of it
      # whether it read them or not.
      # ADR 0029's own step 3 — the argument-resolution logic itself is
      # `Binding.resolve`'s now, shared with `SagaInterpreter#dispatch_args`;
      # a policy's own source chain is the shortest one that module
      # supports — a single source, the merged payload — matching
      # `Binding.resolve`'s own "no `ReactionContext`" case exactly.
      def trigger_args(policy, event, extra = {})
        payload = event.payload.transform_keys(&:to_sym).merge(extra)
        return payload if policy.with_spec.to_a.empty?

        args = Binding.resolve(policy.with_spec, [->(name) { payload[name] }])

        # THE RAW INPUTS `args` WAS RESOLVED FROM — same additive,
        # Ruby-only shape SagaInterpreter#deliver_saga_dispatch's own
        # saga_dispatch_log gets, for Properties.dispatch_binding_
        # fidelity's own independent re-derivation of Policy#with_spec's
        # 2-branch resolution (Symbol → payload lookup, anything else →
        # literal — a policy holds no correlation and no memory, so
        # `payload` — the merged event-payload-plus-fan-out-row source —
        # is the WHOLE source, unlike a saga's own 4-branch one).
        @registry.policy_dispatch_log << { policy: policy.name, on: event.name, payload: payload,
                                            with_spec: policy.with_spec, args: args }
        args
      end

      # RESOLVES `target` ("Domain::Aggregate.Command", the same shape
      # `deliver`'s own caller already built) back to its OWN declared
      # command, then asks IT how it expects to be addressed by a row of
      # `aggregate_name` — see `Behaviour::Command#addressing_key_for`'s
      # own comment for the two shapes that answers. Raises (caught by
      # `deliver_for_each`'s own outer `rescue StandardError`, the same
      # "a defect, not a refusal" treatment `resolve_query_aggregate`'s
      # own `UnknownVerb` already gets one level up) rather than
      # silently falling back on a guess when the target command cannot
      # be resolved, or genuinely cannot be addressed by this aggregate
      # at all — either is a domain-authoring mistake worth surfacing
      # loudly, not a row this fan-out simply skips.
      def addressing_key_for(target, aggregate_name)
        target_domain, target_aggregate_name, target_command_name = Naming.split_verb(target)
        command = @registry.bluebook(target_domain)&.aggregate(target_aggregate_name)&.command(target_command_name)
        raise UnknownVerb, "for_each's own trigger #{target.inspect} does not resolve to a declared command" unless command

        key = command.addressing_key_for(aggregate_name)
        return key if key

        raise ArgumentError,
              "#{target} cannot be addressed by a row of #{aggregate_name} — it declares no self-reference to " \
              "#{aggregate_name} and no reference-typed attribute targeting it"
      end

      # ISOLATED PER ROW, same as a saga's own per-leg dispatch
      # (`SagaInterpreter#deliver_saga_dispatch`) — before this, a defect
      # in ONE row had no rescue of its own here, so it propagated out of
      # the whole `Array(rows).map` in `deliver_for_each` and was caught
      # by THAT method's own outer `rescue StandardError` as a single
      # aggregate defect for the entire fan-out, silently discarding
      # whatever OTHER rows had already succeeded. Retried up to
      # `MAX_DEFECT_RETRIES` times first, same reasoning as `deliver`'s
      # own singleton path — a `for_each` policy is still stateless (no
      # correlation, no memory to compensate), so retry is the only
      # saga-shaped behaviour that transfers; there is nothing here to
      # `unwind`.
      def deliver_for_each_row(target, record, args, row)
        row_record = record.merge(for_row: row[:id])

        return row_record.merge(Reaction.depth_ceiling_record(@door)) if Reaction.depth_ceiling_reached?(@door)

        # ALREADY MERGED, by `trigger_args` — the row key belongs in the
        # source a `with:` projection reads FROM, not bolted onto its
        # result, or a projection could never name the row it acts on.
        outcome = Reaction.deliver_dispatch(max_retries:  MAX_DEFECT_RETRIES,
                                            on_exhausted: lambda { |attempt, error|
                                              warn "[hecksagain] defect in reaction — policy #{record[:policy]} on #{record[:on]} " \
                                                   "firing #{target} for row #{row[:id].inspect} after #{attempt} attempts: #{error.class}: #{error.message}"
                                            }) { @door.reenter(target, **args) }

        row_record.merge(outcome)
      end

      # `for_each`'s own QUERY route moved onto the Policy itself
      # (Behaviour::Policy#for_each_route) — one reading the interpreter
      # and the fuzzer's fan-out property both call, rather than the
      # same split spelled twice. The reference-KEY the dispatch itself
      # uses is `addressing_key_for`, above — a property of the TARGET
      # COMMAND, not of the policy, so it lives on `Behaviour::Command`
      # instead.

      def resolve_query_aggregate(domain, aggregate_name, verb)
        bluebook = @registry.bluebook(domain) ||
                   raise(UnknownVerb, RefusalWording.render("UnknownVerb", "no_domain", domain: domain.inspect, verb: verb))
        bluebook.aggregate(aggregate_name) ||
          raise(UnknownVerb, RefusalWording.render("UnknownVerb", "no_aggregate",
                                                   domain: domain, aggregate: aggregate_name.inspect))
      end
    end
  end
end

module Hecksagain
  module Bluebook
    module DSL
      class PolicyBuilder
        def initialize(name)
          @name = name
        end

        def on(event_name) = @on_event = event_name.to_s

        def trigger(command_name) = @trigger_command = command_name.to_s

        def across(domain_name) = @target_domain = domain_name.to_s

        # `where field: value` -- vendored addition, not (yet) upstream
        # hecksagain (migration plan task 8): a conditional policy
        # trigger, gating whether the policy fires on the triggering
        # EVENT'S OWN PAYLOAD (not a stored-record query the way an
        # aggregate query's `where` is) -- deciderate's own comment
        # names it exactly : "the where-guard IS the 'round complete'
        # condition -- the saga," AdvanceRound firing only when
        # `games_remaining: 0` rides the ResolutionRecorded event. See
        # Runtime::PolicyInterpreter#policies_for's own comment for the
        # evaluation side.
        def where(**conditions)
          (@wheres ||= {}).merge!(conditions.transform_keys(&:to_sym))
        end

        # `for_each from: "Aggregate.query_name", where: { field:
        # from_event(:x) }` -- vendored addition, not (yet) upstream
        # hecksagain (migration plan task 8): a policy-level fan-out,
        # the SAME shape as `dispatch ..., for_each:` already built for
        # saga handlers, except a policy has no saga instance to source
        # from -- every `where:` value resolves against the triggering
        # EVENT's payload only. deciderate's own SettleVotesOnPop names
        # it exactly : "a pop settles the bubble's live votes" -- one
        # Vote.Settle per row `Vote.ForBubble` returns, not one dispatch
        # total. See Runtime::PolicyInterpreter#deliver's own comment
        # for the evaluation side.
        def for_each(from:, where: {})
          @for_each = { from: from.to_s, where: where }
        end

        # `from_event(:field)` -- vendored addition, not (yet) upstream
        # hecksagain (migration plan task 8): the SAME trivial sugar as
        # HandlerBuilder's own `from_event` (a PM handler's sibling) --
        # returns the bare Symbol, relying on `for_each`'s `where:` hash
        # resolving a Symbol value against the triggering event's
        # payload at delivery time, exactly like a `with:` spec already
        # does for `dispatch`.
        def from_event(field, default: nil) = field

        def build
          IR::Policy.new(
            name:            @name,
            on_event:        @on_event,
            trigger_command: @trigger_command,
            target_domain:   @target_domain,
            wheres:          @wheres || {},
            for_each:        @for_each
          )
        end

        def self.build(name, &block)
          builder = new(name)
          builder.instance_eval(&block) if block
          builder.build
        end
      end
    end
  end
end

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

        def build
          IR::Policy.new(
            name:            @name,
            on_event:        @on_event,
            trigger_command: @trigger_command,
            target_domain:   @target_domain,
            wheres:          @wheres || {}
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

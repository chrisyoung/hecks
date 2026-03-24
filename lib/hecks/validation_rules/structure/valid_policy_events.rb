# Hecks::ValidationRules::Structure::ValidPolicyEvents
#
# Produces warnings (not errors) when policies listen for events not defined
# in this domain. Cross-domain events are valid -- they arrive via the shared
# event bus -- so this is informational only.
#
module Hecks
  module ValidationRules
    module Structure
    class ValidPolicyEvents < BaseRule
      def errors
        []
      end

      def warnings
        result = []
        all_events = @domain.aggregates.flat_map { |a| a.events.map(&:name) }

        @domain.aggregates.each do |agg|
          agg.policies.each do |policy|
            unless all_events.include?(policy.event_name)
              hint = all_events.any? ? " Known events: #{all_events.join(', ')}." : ""
              result << "Policy #{policy.name} in #{agg.name} listens for #{policy.event_name} (not in this domain — must come from another domain).#{hint}"
            end
          end
        end

        @domain.policies.each do |policy|
          unless all_events.include?(policy.event_name)
            hint = all_events.any? ? " Known events: #{all_events.join(', ')}." : ""
            result << "Domain policy #{policy.name} listens for #{policy.event_name} (not in this domain — must come from another domain).#{hint}"
          end
        end

        result
      end
    end
    end
  end
end

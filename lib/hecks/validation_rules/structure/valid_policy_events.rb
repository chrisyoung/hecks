module Hecks
  module ValidationRules
    module Structure
    # Policy events must exist (can be cross-context)
    class ValidPolicyEvents < BaseRule
      def errors
        result = []
        all_events = @domain.aggregates.flat_map { |a| a.events.map(&:name) }

        @domain.aggregates.each do |agg|
          agg.policies.each do |policy|
            unless all_events.include?(policy.event_name)
              result << "Policy #{policy.name} in #{agg.name} references unknown event: #{policy.event_name}"
            end
          end
        end
        result
      end
    end
    end
  end
end

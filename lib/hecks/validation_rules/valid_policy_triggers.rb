module Hecks
  module ValidationRules
    # Policy trigger must name an existing command somewhere in the domain
    class ValidPolicyTriggers < BaseRule
      def errors
        result = []
        all_commands = @domain.aggregates.flat_map { |a| a.commands.map(&:name) }

        @domain.aggregates.each do |agg|
          agg.policies.each do |policy|
            unless all_commands.include?(policy.trigger_command)
              result << "Policy #{policy.name} in #{agg.name} triggers unknown command: #{policy.trigger_command}. The triggered command must exist in the domain."
            end
          end
        end
        result
      end
    end
  end
end

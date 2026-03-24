# Hecks::ValidationRules::Structure::ValidPolicyTriggers
#
# Rejects policies whose trigger_command does not match any command
# in the domain. Part of the ValidationRules::Structure group --
# run by Hecks.validate.
#
module Hecks
  module ValidationRules
    module Structure
    # Policy trigger must name an existing command somewhere in the domain
    class ValidPolicyTriggers < BaseRule
      def errors
        result = []
        all_commands = @domain.aggregates.flat_map { |a| a.commands.map(&:name) }

        @domain.aggregates.each do |agg|
          agg.policies.select(&:reactive?).each do |policy|
            unless all_commands.include?(policy.trigger_command)
              hint = all_commands.any? ? " Available commands: #{all_commands.join(', ')}." : ""
              result << "Policy #{policy.name} in #{agg.name} triggers unknown command: #{policy.trigger_command}.#{hint}"
            end
          end
        end

        @domain.policies.select(&:reactive?).each do |policy|
          unless all_commands.include?(policy.trigger_command)
            hint = all_commands.any? ? " Available commands: #{all_commands.join(', ')}." : ""
            result << "Domain policy #{policy.name} triggers unknown command: #{policy.trigger_command}.#{hint}"
          end
        end

        result
      end
    end
    end
  end
end

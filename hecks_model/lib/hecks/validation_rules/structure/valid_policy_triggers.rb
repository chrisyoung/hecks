# Hecks::ValidationRules::Structure::ValidPolicyTriggers
#
# Validates that reactive policies reference commands that actually exist
# in the domain. A reactive policy's +trigger_command+ must match a command
# defined on some aggregate; otherwise the policy can never fire.
#
# Checks both aggregate-level reactive policies and domain-level reactive
# policies. Non-reactive policies (those without a trigger_command) are skipped.
#
# Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
#
module Hecks
  module ValidationRules
    module Structure
    # Policy trigger must name an existing command somewhere in the domain.
    class ValidPolicyTriggers < BaseRule
      # Checks all reactive policies (aggregate-scoped and domain-level) and
      # returns errors for any whose +trigger_command+ does not match a known
      # command in the domain. Includes a hint listing available commands.
      #
      # @return [Array<String>] error messages for policies with unknown trigger commands
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

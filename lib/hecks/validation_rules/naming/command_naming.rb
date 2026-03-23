# Hecks::ValidationRules::Naming::CommandNaming
#
# Rejects command names that do not start with a verb.
#
module Hecks
  module ValidationRules
    module Naming
    # Command names should start with a verb
    class CommandNaming < BaseRule
      COMMAND_VERBS = %w[
        Create Update Delete Remove Add Set Place Cancel Submit
        Approve Reject Assign Start Stop Complete Close Open
        Send Publish Register Change Move Transfer Reserve
        Activate Deactivate Enable Disable Archive Restore
        Prepare Process Schedule Notify Verify Confirm Check
        Import Export Generate Build Release Deploy Promote
      ].freeze

      def errors
        result = []
        @domain.aggregates.each do |agg|
          agg.commands.each do |cmd|
            first_word = cmd.name.split(/(?=[A-Z])/).first
            unless COMMAND_VERBS.include?(first_word)
              result << "Command #{cmd.name} in #{agg.name} doesn't start with a verb. Commands should express intent (e.g. Create#{agg.name}, Update#{agg.name})."
            end
          end
        end
        result
      end
    end
    end
  end
end

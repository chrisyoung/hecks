# Hecks::ValidationRules::Naming::CommandNaming
#
# Rejects command names that do not start with a recognized verb.
# Domains can add custom verbs via `verbs "Ship", "Deliver"` in the DSL.
#
module Hecks
  module ValidationRules
    module Naming
    class CommandNaming < BaseRule
      DEFAULT_VERBS = %w[
        Create Update Delete Remove Add Set Place Cancel Submit
        Approve Reject Assign Start Stop Complete Close Open
        Send Publish Register Change Move Transfer Reserve
        Activate Deactivate Enable Disable Archive Restore
        Prepare Process Schedule Notify Verify Confirm Check
        Import Export Generate Build Release Deploy Promote
        Ship Deliver Fulfill Pay Charge Refund Bill Mark
      ].freeze

      def errors
        allowed = DEFAULT_VERBS + (@domain.respond_to?(:verbs) ? @domain.verbs : [])
        result = []
        @domain.aggregates.each do |agg|
          agg.commands.each do |cmd|
            first_word = cmd.name.split(/(?=[A-Z])/).first
            unless allowed.include?(first_word)
              result << "Command #{cmd.name} in #{agg.name} doesn't start with a verb. Commands should express intent (e.g. Create#{agg.name}, Update#{agg.name}). Add custom verbs with: verbs \"#{first_word}\""
            end
          end
        end
        result
      end
    end
    end
  end
end

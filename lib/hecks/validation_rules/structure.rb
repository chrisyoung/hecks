# Hecks::ValidationRules::Structure
#
# Rules that enforce structural completeness: aggregates have commands,
# commands have attributes, policies reference valid events and triggers.
#
module Hecks
  module ValidationRules
    module Structure
      autoload :AggregatesHaveCommands, "hecks/validation_rules/structure/aggregates_have_commands"
      autoload :CommandsHaveAttributes, "hecks/validation_rules/structure/commands_have_attributes"
      autoload :ValidPolicyEvents,      "hecks/validation_rules/structure/valid_policy_events"
      autoload :ValidPolicyTriggers,    "hecks/validation_rules/structure/valid_policy_triggers"
    end
  end
end

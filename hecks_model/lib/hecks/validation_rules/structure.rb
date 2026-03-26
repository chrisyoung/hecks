module Hecks
  module ValidationRules

    # Hecks::ValidationRules::Structure
    #
    # Structural completeness rules for domain validation. This module groups rules
    # that enforce the domain model has the minimum required components:
    #
    # - +AggregatesHaveCommands+ -- every aggregate must have at least one command
    # - +CommandsHaveAttributes+ -- every command must have at least one attribute
    # - +ValidPolicyEvents+ -- policies should listen for events that exist (advisory warnings)
    # - +ValidPolicyTriggers+ -- reactive policies must trigger commands that exist
    #
    # All rules are autoloaded and executed as part of +Hecks.validate+.
    #
    module Structure
      autoload :AggregatesHaveCommands, "hecks/validation_rules/structure/aggregates_have_commands"
      autoload :CommandsHaveAttributes, "hecks/validation_rules/structure/commands_have_attributes"
      autoload :ValidPolicyEvents,      "hecks/validation_rules/structure/valid_policy_events"
      autoload :ValidPolicyTriggers,    "hecks/validation_rules/structure/valid_policy_triggers"
    end
  end
end

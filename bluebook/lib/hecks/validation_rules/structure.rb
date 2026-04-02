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
    # - +SingleAttributeAggregate+ -- warns when aggregate has only 1 attribute and no VOs/entities
    # - +TooManyCommands+ -- warns when aggregate has 10+ commands (consider splitting)
    #
    # All rules are autoloaded and executed as part of +Hecks.validate+.
    #
    # Hecks::ValidationRules::Structure
    #
    # Structural completeness and complexity rules for domain validation.
    # Groups rules for minimum components, size thresholds, and cohesion:
    #
    # - +AggregatesHaveCommands+ -- every aggregate must have at least one command
    # - +CommandsHaveAttributes+ -- every command must have at least one attribute
    # - +ValidPolicyEvents+ -- policies should listen for events that exist
    # - +ValidPolicyTriggers+ -- reactive policies must trigger commands that exist
    # - +SingleAttributeAggregate+ -- warns when aggregate has only 1 attribute
    # - +TooManyCommands+ -- warns when aggregate has 10+ commands
    # - +TooManyAttributes+ -- warns when aggregate has 8+ attributes
    # - +TooManyValueObjects+ -- warns when aggregate has 5+ value objects
    # - +MissingLifecycle+ -- warns when status attribute lacks lifecycle
    # - +CohesionAnalysis+ -- warns when commands touch disjoint attributes
    # - +GodAggregate+ -- warns when multiple complexity signals co-occur
    #
    module Structure
      autoload :AggregatesHaveCommands,   "hecks/validation_rules/structure/aggregates_have_commands"
      autoload :CommandsHaveAttributes,   "hecks/validation_rules/structure/commands_have_attributes"
      autoload :ValidPolicyEvents,        "hecks/validation_rules/structure/valid_policy_events"
      autoload :ValidPolicyTriggers,      "hecks/validation_rules/structure/valid_policy_triggers"
      autoload :NoPiiInIdentity,          "hecks/validation_rules/structure/no_pii_in_identity"
      autoload :SingleAttributeAggregate, "hecks/validation_rules/structure/single_attribute_aggregate"
      autoload :TooManyCommands,          "hecks/validation_rules/structure/too_many_commands"
      autoload :TooManyAttributes,        "hecks/validation_rules/structure/too_many_attributes"
      autoload :TooManyValueObjects,      "hecks/validation_rules/structure/too_many_value_objects"
      autoload :MissingLifecycle,         "hecks/validation_rules/structure/missing_lifecycle"
      autoload :CohesionAnalysis,         "hecks/validation_rules/structure/cohesion_analysis"
      autoload :GodAggregate,             "hecks/validation_rules/structure/god_aggregate"
    end
  end
end

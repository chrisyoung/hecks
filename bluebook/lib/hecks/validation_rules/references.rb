module Hecks
  module ValidationRules

    # Hecks::ValidationRules::References
    #
    # Reference integrity rules for domain validation. This module groups rules
    # that enforce correct usage of aggregate references:
    #
    # - +ValidReferences+ -- references must target existing aggregate roots (not value objects or entities)
    # - +NoBidirectionalReferences+ -- no mutual A->B and B->A references between aggregates
    # - +NoSelfReferences+ -- aggregates cannot reference themselves
    # - +NoForeignKeyAttributes+ -- warns about _id attributes that should be reference_to
    # - +BoundaryAnalysis+ -- warns about Big Ball of Mud (density, hubs, cycles)
    # - +FanOut+ -- warns when an aggregate has too many outgoing references
    #
    # All rules are autoloaded and executed as part of +Hecks.validate+.
    #
    module References
      autoload :ValidReferences,           "hecks/validation_rules/references/valid_references"
      autoload :NoBidirectionalReferences, "hecks/validation_rules/references/no_bidirectional_references"
      autoload :NoSelfReferences,          "hecks/validation_rules/references/no_self_references"
      autoload :NoForeignKeyAttributes,    "hecks/validation_rules/references/no_foreign_key_attributes"
      autoload :BoundaryAnalysis,          "hecks/validation_rules/references/boundary_analysis"
      autoload :FanOut,                    "hecks/validation_rules/references/fan_out"
    end
  end
end

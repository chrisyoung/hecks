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
    #
    # All rules are autoloaded and executed as part of +Hecks.validate+.
    #
    # Hecks::ValidationRules::References
    #
    # Reference integrity and topology rules for domain validation:
    #
    # - +ValidReferences+ -- references must target existing aggregate roots
    # - +NoBidirectionalReferences+ -- no mutual A->B and B->A references
    # - +NoSelfReferences+ -- aggregates cannot reference themselves
    # - +NoForeignKeyAttributes+ -- warns about _id String attributes
    # - +BoundaryAnalysis+ -- warns about density, hubs, and cycles
    # - +FanOut+ -- warns when aggregate has 4+ outgoing references
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

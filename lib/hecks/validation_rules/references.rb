# Hecks::ValidationRules::References
#
# Rules that enforce reference integrity: valid targets, no bidirectional
# references, no self-references, no value object references.
#
module Hecks
  module ValidationRules
    module References
      autoload :ValidReferences,           "hecks/validation_rules/references/valid_references"
      autoload :NoBidirectionalReferences, "hecks/validation_rules/references/no_bidirectional_references"
      autoload :NoSelfReferences,          "hecks/validation_rules/references/no_self_references"
      autoload :NoValueObjectReferences,   "hecks/validation_rules/references/no_value_object_references"
    end
  end
end

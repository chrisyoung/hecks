# Hecks::ValidationRegistryMethods
#
# Registry for domain validation rules. Each rule class registers itself
# so the Validator can discover rules without a hardcoded constant list.
#
#   Hecks.register_validation_rule(ValidationRules::Naming::UniqueAggregateNames)
#   Hecks.validation_rules  # => [UniqueAggregateNames, ...]
#
module Hecks
  module ValidationRegistryMethods
    extend ModuleDSL

    lazy_registry(:validation_rule_registry, private: true) { [] }

    def validation_rules
      validation_rule_registry.dup
    end

    def register_validation_rule(rule_class)
      validation_rule_registry << rule_class unless validation_rule_registry.include?(rule_class)
    end
  end
end

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
    def validation_rules
      @validation_rules.dup
    end

    def register_validation_rule(rule_class)
      @validation_rules << rule_class unless @validation_rules.include?(rule_class)
    end
  end
end

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
      validation_rule_registry.all
    end

    def register_validation_rule(rule_class)
      validation_rule_registry.register(rule_class)
    end

    def deregister_validation_rule(rule_class)
      validation_rule_registry.deregister(rule_class)
    end

    # Define a custom world goal with a builder DSL. The goal name becomes
    # available in the +world_goals+ keyword and activates its validation
    # rule when declared on a domain.
    #
    #   Hecks.define_goal(:audit_trail) do
    #     requires_extension :audit
    #     validate { |domain| [] }
    #   end
    #
    # @param name [Symbol] the goal name (used in +world_goals :name+)
    # @yield block evaluated in the context of GoalBuilder
    # @return [Class] the generated BaseRule subclass
    def define_goal(name, &block)
      builder = ValidationRules::WorldGoals::GoalBuilder.new(name)
      builder.instance_eval(&block) if block
      builder.build!
    end

    private

    def validation_rule_registry
      @validation_rule_registry ||= SetRegistry.new
    end
  end
end

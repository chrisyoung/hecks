module Hecks
  module ValidationRules
    module Naming

    # Hecks::ValidationRules::Naming::FunctionNameCollisions
    #
    # Validates that pure function names do not collide with regular
    # attribute or computed attribute names on the same aggregate.
    # Such collisions would generate a method that shadows an accessor.
    #
    # Part of the ValidationRules::Naming group -- run by +Hecks.validate+.
    #
    #   rule = FunctionNameCollisions.new(domain)
    #   rule.errors  # => ["Pizza: function 'name' collides with a regular attribute"]
    #
    class FunctionNameCollisions < BaseRule
      # Checks all aggregates for name collisions between functions and attributes.
      #
      # @return [Array<String>] error messages for each collision found
      def errors
        result = []
        @domain.aggregates.each do |agg|
          attr_names = agg.attributes.map(&:name).map(&:to_sym)
          computed_names = (agg.computed_attributes || []).map(&:name).map(&:to_sym)
          taken = attr_names + computed_names

          (agg.functions || []).each do |fn|
            if taken.include?(fn.name.to_sym)
              result << error("#{agg.name}: function '#{fn.name}' collides with an attribute or computed attribute",
                hint: "Rename the function to avoid the collision")
            end
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(FunctionNameCollisions)
    end
  end
end

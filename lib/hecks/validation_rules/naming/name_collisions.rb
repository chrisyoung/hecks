# Hecks::ValidationRules::Naming::NameCollisions
#
# Rejects aggregate root names that collide with their own value object
# names. Part of the ValidationRules::Naming group -- run by Hecks.validate.
#
module Hecks
  module ValidationRules
    module Naming
    # Aggregate root name must not collide with its value object names
    class NameCollisions < BaseRule
      def errors
        result = []
        @domain.aggregates.each do |agg|
          agg.value_objects.each do |vo|
            if vo.name == agg.name
              result << "#{agg.name} has a value object with the same name as the aggregate root. Rename the value object."
            end
          end
        end
        result
      end
    end
    end
  end
end

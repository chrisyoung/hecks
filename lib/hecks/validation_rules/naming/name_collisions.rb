# Hecks::ValidationRules::Naming::NameCollisions
#
# Rejects aggregate and value object name collisions.
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

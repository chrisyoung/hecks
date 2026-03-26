# Hecks::ValidationRules::References::NoValueObjectReferences
#
# Validates that value objects do not contain +reference_to+ attributes.
# Value objects represent values (not identity), so they should not hold
# references to aggregate roots. The reference should be moved to the
# parent aggregate instead.
#
# Part of the ValidationRules::References group -- run by +Hecks.validate+.
#
module Hecks
  module ValidationRules
    module References
    # Value objects should not contain reference_to attributes.
    class NoValueObjectReferences < BaseRule
      # Checks each value object within each aggregate for reference attributes.
      #
      # @return [Array<String>] error messages for each reference found on a value object
      def errors
        result = []
        @domain.aggregates.each do |agg|
          agg.value_objects.each do |vo|
            vo.attributes.select(&:reference?).each do |attr|
              result << "Value object #{vo.name} in #{agg.name} contains a reference to #{attr.type}. Value objects can't reference aggregates. Move the reference to the parent aggregate #{agg.name} instead."
            end
          end
        end
        result
      end
    end
    end
  end
end

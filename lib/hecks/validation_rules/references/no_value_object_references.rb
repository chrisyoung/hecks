# Hecks::ValidationRules::References::NoValueObjectReferences
#
# Rejects reference attributes on value objects. Value objects are about
# values, not identity. Part of the ValidationRules::References group --
# run by Hecks.validate.
#
module Hecks
  module ValidationRules
    module References
    # Value objects should not contain reference_to attributes
    class NoValueObjectReferences < BaseRule
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

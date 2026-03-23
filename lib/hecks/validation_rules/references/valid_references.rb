# Hecks::ValidationRules::References::ValidReferences
#
# Rejects references to non-existent aggregates and references that
# target value objects instead of aggregate roots. Part of the
# ValidationRules::References group -- run by Hecks.validate.
#
module Hecks
  module ValidationRules
    module References
    # References must target aggregate roots
    class ValidReferences < BaseRule
      def errors
        result = []
        all_aggregate_names = @domain.aggregates.map(&:name)
        all_vo_names = @domain.aggregates.flat_map { |a| a.value_objects.map(&:name) }

        @domain.aggregates.each do |agg|
          agg.attributes.select(&:reference?).each do |attr|
            ref_name = attr.type.to_s

            # Check if referencing a value object instead of an aggregate
            if all_vo_names.include?(ref_name) && !all_aggregate_names.include?(ref_name)
              result << "#{agg.name} references #{ref_name} which is a value object, not an aggregate root. References must target aggregate roots."
              next
            end

            if all_aggregate_names.include?(ref_name)
              next # valid: same domain aggregate root
            end

            result << "#{agg.name} references unknown aggregate: #{ref_name}"
          end
        end
        result
      end
    end
    end
  end
end

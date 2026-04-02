module Hecks
  module ValidationRules
    module References

    # Hecks::ValidationRules::References::ValidReferences
    #
    # Validates that all +reference_to+ attributes target existing aggregate roots.
    # Catches three kinds of mistakes:
    # 1. Referencing a value object instead of an aggregate root
    # 2. Referencing an entity instead of an aggregate root
    # 3. Referencing a name that does not exist in the domain at all
    #
    # Each error includes an actionable hint (promote to aggregate, reference
    # the owning aggregate, or lists available aggregates).
    #
    # Part of the ValidationRules::References group -- run by +Hecks.validate+.
    #
    # References must target valid types (aggregates, or qualified entity/VO paths).
    class ValidReferences < BaseRule
      # Checks each aggregate's reference attributes to ensure they point at
      # existing types. Handles simple names, 2-segment qualified paths
      # (Aggregate::Entity), and cross-domain references.
      #
      # @return [Array<String>] error messages for invalid references
      def errors
        result = []
        all_aggregate_names = @domain.aggregates.map(&:name)
        agg_by_name = @domain.aggregates.each_with_object({}) { |a, h| h[a.name] = a }

        @domain.aggregates.each do |agg|
          (agg.references || []).each do |ref|
            next if ref.domain
            errs = ref.aggregate ? validate_qualified(ref, agg, agg_by_name) : validate_simple(ref, agg, agg_by_name)
            result.concat(errs)
          end
        end
        result
      end

      private

      def validate_simple(ref, agg, agg_by_name)
        all_agg_names = agg_by_name.keys
        all_vo_names = agg_by_name.values.flat_map { |a| a.value_objects.map(&:name) }
        all_entity_names = agg_by_name.values.flat_map { |a| a.entities.map(&:name) }
        ref_name = ref.type.to_s

        if all_vo_names.include?(ref_name) && !all_agg_names.include?(ref_name)
          return [error("#{agg.name} references #{ref_name} which is a value object, not an aggregate root",
            hint: "Move #{ref_name} to its own aggregate or reference the aggregate that owns it")]
        end

        if all_entity_names.include?(ref_name) && !all_agg_names.include?(ref_name)
          return [error("#{agg.name} references #{ref_name} which is an entity, not an aggregate root",
            hint: "Promote #{ref_name} to its own aggregate or reference the aggregate that owns it")]
        end

        return [] if all_agg_names.include?(ref_name)

        available = all_agg_names.reject { |n| n == agg.name }
        fix = available.any? ? "Available aggregates: #{available.join(', ')}" : "Define the target aggregate first"
        [error("#{agg.name} references unknown aggregate: #{ref_name}", hint: fix)]
      end

      def validate_qualified(ref, agg, agg_by_name)
        target_agg = agg_by_name[ref.aggregate]
        unless target_agg
          available = agg_by_name.keys.reject { |n| n == agg.name }
          fix = available.any? ? "Available aggregates: #{available.join(', ')}" : "Define the target aggregate first"
          return [error("#{agg.name} references '#{ref.qualified_path}' but aggregate '#{ref.aggregate}' not found",
            hint: fix)]
        end
        target_types = target_agg.value_objects.map(&:name) + target_agg.entities.map(&:name)
        return [] if target_types.include?(ref.type)
        available = target_types.any? ? "Available types in #{ref.aggregate}: #{target_types.join(', ')}" : "#{ref.aggregate} has no entities or value objects"
        [error("#{agg.name} references '#{ref.qualified_path}' but '#{ref.type}' not found in aggregate '#{ref.aggregate}'",
          hint: available)]
      end
    end
    Hecks.register_validation_rule(ValidReferences)
    end
  end
end

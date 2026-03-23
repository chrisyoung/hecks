# Hecks::ValidationRules::References::ValidReferences
#
# Rejects references to non-existent aggregates.
#
module Hecks
  module ValidationRules
    module References
    # References must resolve within the same context and target aggregate roots
    class ValidReferences < BaseRule
      def errors
        result = []
        all_vo_names = @domain.aggregates.flat_map { |a| a.value_objects.map(&:name) }

        @domain.contexts.each do |ctx|
          context_aggregate_names = ctx.aggregates.map(&:name)

          ctx.aggregates.each do |agg|
            agg.attributes.select(&:reference?).each do |attr|
              ref_name = attr.type.to_s

              # Check if referencing a value object instead of an aggregate
              if all_vo_names.include?(ref_name) && !context_aggregate_names.include?(ref_name)
                prefix = ctx.default? ? "" : "#{ctx.name}: "
                result << "#{prefix}#{agg.name} references #{ref_name} which is a value object, not an aggregate root. References must target aggregate roots."
                next
              end

              if context_aggregate_names.include?(ref_name)
                next # valid: same context aggregate root
              end

              # Check if it exists in another context
              other_context = @domain.contexts.find do |other|
                other != ctx && other.aggregates.any? { |a| a.name == ref_name }
              end

              if other_context
                prefix = ctx.default? ? "" : "#{ctx.name}: "
                other_name = other_context.default? ? "" : " (in #{other_context.name})"
                result << "#{prefix}#{agg.name} references #{ref_name}#{other_name} across context boundary. Use events/policies for cross-context communication."
              else
                prefix = ctx.default? ? "" : "#{ctx.name}: "
                result << "#{prefix}#{agg.name} references unknown aggregate: #{ref_name}"
              end
            end
          end
        end
        result
      end
    end
    end
  end
end

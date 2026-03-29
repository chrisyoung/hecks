# Hecks::ValidationRules::References::NoImplicitForeignKeys
#
# Flags attributes named *_id with type String that look like
# foreign keys but aren't declared as reference_to. These should
# be explicit references so the web explorer can render dropdowns
# and the domain model documents its relationships.
#
# Self-referential IDs (e.g., policy_id on GovernancePolicy) are
# excluded — those are handled by the command self-ref pattern.
#
#   # Bad:  model_id String
#   # Good: attribute :model_id, reference_to("AiModel")
#
module Hecks
  module ValidationRules
    module References
      class NoImplicitForeignKeys < BaseRule
        def errors
          [] # Non-blocking — use warnings instead
        end

        def warnings
          issues = []
          agg_snakes = @domain.aggregates.map { |a| Hecks::Utils.underscore(a.name) }

          @domain.aggregates.each do |agg|
            agg_snake = Hecks::Utils.underscore(agg.name)
            suffixes = agg_snake.split("_").each_index.map { |i|
              agg_snake.split("_").drop(i).join("_")
            }.uniq

            agg.attributes.each do |attr|
              next unless attr.name.to_s.end_with?("_id")
              next if attr.reference?
              # Skip self-referential IDs
              next if suffixes.any? { |s| attr.name.to_s == "#{s}_id" }
              # Skip reserved attributes
              next if Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(attr.name.to_s)
              # Skip IDs whose prefix doesn't match any aggregate name
              prefix = attr.name.to_s.sub(/_id$/, "")
              next unless agg_snakes.any? { |name| name == prefix || name.end_with?("_#{prefix}") }

              issues << "#{agg.name}.#{attr.name} looks like a foreign key but is declared as String. " \
                        "Use reference_to(\"AggregateName\") to make the relationship explicit."
            end
          end
          issues
        end
      Hecks.register_validation_rule(NoImplicitForeignKeys)
      end
    end
  end
end

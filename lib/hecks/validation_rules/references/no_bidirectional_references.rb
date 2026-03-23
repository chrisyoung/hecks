module Hecks
  module ValidationRules
    module References
    # No A -> B and B -> A
    class NoBidirectionalReferences < BaseRule
      def errors
        result = []
        @domain.contexts.each do |ctx|
          refs = {}
          ctx.aggregates.each do |agg|
            targets = agg.attributes.select(&:reference?).map { |a| a.type.to_s }
            refs[agg.name] = targets
          end

          refs.each do |agg_name, targets|
            targets.each do |target|
              if refs[target]&.include?(agg_name)
                pair = [agg_name, target].sort
                prefix = ctx.default? ? "" : "#{ctx.name}: "
                error = "#{prefix}Bidirectional reference between #{pair[0]} and #{pair[1]}. Aggregates should not reference each other — one side should use events/policies instead."
                result << error unless result.include?(error)
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

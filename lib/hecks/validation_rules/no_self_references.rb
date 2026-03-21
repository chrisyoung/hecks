module Hecks
  module ValidationRules
    # An aggregate should not reference itself
    class NoSelfReferences < BaseRule
      def errors
        result = []
        @domain.aggregates.each do |agg|
          agg.attributes.select(&:reference?).each do |attr|
            if attr.type.to_s == agg.name
              result << "#{agg.name} references itself. An aggregate already has its own identity — self-references are unnecessary."
            end
          end
        end
        result
      end
    end
  end
end

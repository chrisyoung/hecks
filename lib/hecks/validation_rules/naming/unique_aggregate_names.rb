# Hecks::ValidationRules::Naming::UniqueAggregateNames
#
# Rejects duplicate aggregate names within a context.
#
module Hecks
  module ValidationRules
    module Naming
    # Aggregates must be unique within each context
    class UniqueAggregateNames < BaseRule
      def errors
        result = []
        @domain.contexts.each do |ctx|
          names = ctx.aggregates.map(&:name)
          duplicates = names.select { |n| names.count(n) > 1 }.uniq

          duplicates.each do |name|
            prefix = ctx.default? ? "" : "#{ctx.name}: "
            result << "#{prefix}Duplicate aggregate name: #{name}"
          end
        end
        result
      end
    end
    end
  end
end

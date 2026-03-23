# Hecks::ValidationRules::Naming::UniqueAggregateNames
#
# Rejects duplicate aggregate names within a domain. Part of the
# ValidationRules::Naming group -- run by Hecks.validate.
#
module Hecks
  module ValidationRules
    module Naming
    # Aggregates must have unique names
    class UniqueAggregateNames < BaseRule
      def errors
        names = @domain.aggregates.map(&:name)
        duplicates = names.select { |n| names.count(n) > 1 }.uniq

        duplicates.map do |name|
          "Duplicate aggregate name: #{name}"
        end
      end
    end
    end
  end
end

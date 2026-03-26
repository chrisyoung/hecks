# Hecks::ValidationRules::References::NoSelfReferences
#
# Validates that aggregates do not reference themselves. Self-references
# indicate a modeling issue -- the referenced concept should be a value
# object or entity within the aggregate boundary instead.
#
# Part of the ValidationRules::References group -- run by +Hecks.validate+.
#
module Hecks
  module ValidationRules
    module References
    # An aggregate should not reference itself.
    class NoSelfReferences < BaseRule
      # Checks each aggregate's reference attributes for any that target
      # the same aggregate.
      #
      # @return [Array<String>] error messages for each self-referencing attribute found
      def errors
        result = []
        @domain.aggregates.each do |agg|
          agg.attributes.select(&:reference?).each do |attr|
            if attr.type.to_s == agg.name
              result << "#{agg.name} references itself. Use a value object or entity inside the aggregate instead of referencing the aggregate itself."
            end
          end
        end
        result
      end
    end
    end
  end
end

module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::TooManyValueObjects
    #
    # Advisory warning for aggregates that have 5 or more value objects.
    # An aggregate with many value objects may have grown beyond its
    # natural boundary and should be considered for splitting.
    #
    # Threshold is THRESHOLD = 5 value objects.
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     value_object "Address" { ... }
    #     value_object "LineItem" { ... }
    #     # ... 5+ value objects
    #   end
    #
    # Would warn: "Order has 5 value objects -- consider splitting the aggregate"
    class TooManyValueObjects < BaseRule
      THRESHOLD = 5

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate with THRESHOLD or more
      # value objects.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          vos = agg.respond_to?(:value_objects) ? agg.value_objects : []
          if vos.size >= THRESHOLD
            result << error("#{agg.name} has #{vos.size} value objects -- consider splitting the aggregate",
              hint: "Some value objects may belong in their own aggregate")
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(TooManyValueObjects)
    end
  end
end

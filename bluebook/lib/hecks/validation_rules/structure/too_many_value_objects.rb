module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::TooManyValueObjects
    #
    # Advisory warning for aggregates that have 5 or more value objects.
    # A high value object count suggests the aggregate boundary is too wide
    # and should be split into smaller aggregates (Evans: Conceptual Contours).
    #
    # Threshold is THRESHOLD = 5 value objects.
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     value_object("A") { attribute :x, String }
    #     value_object("B") { attribute :x, String }
    #     # ... 5 total ...
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

      # Returns a warning for each aggregate whose value object count meets
      # or exceeds THRESHOLD.
      #
      # @return [Array<String>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          vos = agg.respond_to?(:value_objects) ? agg.value_objects : []
          if vos.size >= THRESHOLD
            result << "#{agg.name} has #{vos.size} value objects -- consider splitting the aggregate"
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(TooManyValueObjects)
    end
  end
end

module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::TooManyAttributes
    #
    # Advisory warning for aggregates that have 8 or more attributes.
    # A high attribute count often indicates that the aggregate has taken
    # on too many responsibilities and should be decomposed into value
    # objects or separate aggregates.
    #
    # Threshold is THRESHOLD = 8 attributes.
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     attribute :a, String; attribute :b, String; ... # 8+ attributes
    #   end
    #
    # Would warn: "Order has 8 attributes -- consider extracting value objects"
    class TooManyAttributes < BaseRule
      THRESHOLD = 8

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate whose attribute count meets
      # or exceeds THRESHOLD.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          if agg.attributes.size >= THRESHOLD
            result << error("#{agg.name} has #{agg.attributes.size} attributes -- consider extracting value objects",
              hint: "Group related attributes into value objects to improve cohesion")
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(TooManyAttributes)
    end
  end
end

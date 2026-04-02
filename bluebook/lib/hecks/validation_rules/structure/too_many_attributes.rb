module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::TooManyAttributes
    #
    # Advisory warning for aggregates that have 8 or more attributes on the
    # root entity. A high attribute count is a DDD smell -- the aggregate may
    # be a data clump that should extract value objects to capture cohesive
    # groups of attributes (Evans: Conceptual Contours).
    #
    # Threshold is THRESHOLD = 8 attributes.
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     attribute :a, String
    #     attribute :b, String
    #     # ... 8 total ...
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

      # Returns a warning for each aggregate whose attribute count meets or
      # exceeds THRESHOLD.
      #
      # @return [Array<String>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          if agg.attributes.size >= THRESHOLD
            result << "#{agg.name} has #{agg.attributes.size} attributes -- consider extracting value objects"
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(TooManyAttributes)
    end
  end
end

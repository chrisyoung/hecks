module Hecks
  module ValidationRules
    module References

    # Hecks::ValidationRules::References::FanOut
    #
    # Advisory warning for aggregates that reference 4 or more other
    # aggregates. High fan-out indicates the aggregate depends on too
    # many external concepts and may be doing too much.
    #
    # Threshold is THRESHOLD = 4 outgoing references.
    #
    # Part of the ValidationRules::References group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     reference_to "Pizza"
    #     reference_to "Customer"
    #     reference_to "Delivery"
    #     reference_to "Payment"
    #   end
    #
    # Would warn: "Order references 4 aggregates -- high fan-out"
    class FanOut < BaseRule
      THRESHOLD = 4

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate with THRESHOLD or more
      # outgoing references to other aggregates.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          refs = (agg.references || [])
          if refs.size >= THRESHOLD
            targets = refs.map { |r| r.type.to_s }.join(", ")
            result << error("#{agg.name} references #{refs.size} aggregates (#{targets}) -- high fan-out",
              hint: "Consider introducing a mediator aggregate or domain service")
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(FanOut)
    end
  end
end

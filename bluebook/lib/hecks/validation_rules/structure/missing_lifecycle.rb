module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::MissingLifecycle
    #
    # Advisory warning for aggregates that have a status-like attribute but
    # no lifecycle (state machine) defined. Aggregates with status fields
    # almost always benefit from an explicit lifecycle definition that
    # documents valid transitions (Evans: Conceptual Contours).
    #
    # Detection: any attribute whose name contains "status" or "state".
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     attribute :status, String
    #     command("PlaceOrder") { attribute :qty, Integer }
    #   end
    #
    # Would warn: "Order has a status attribute but no lifecycle -- consider
    #   adding a lifecycle definition"
    class MissingLifecycle < BaseRule
      STATUS_PATTERN = /status|state/i

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate that has a status-like attribute
      # but no lifecycle defined.
      #
      # @return [Array<String>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          has_status = agg.attributes.any? { |a| a.name.to_s.match?(STATUS_PATTERN) }
          has_lifecycle = agg.respond_to?(:lifecycle) && agg.lifecycle
          if has_status && !has_lifecycle
            result << "#{agg.name} has a status attribute but no lifecycle -- consider adding a lifecycle definition"
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(MissingLifecycle)
    end
  end
end

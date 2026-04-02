module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::MissingLifecycle
    #
    # Advisory warning for aggregates that have a :status attribute but
    # no lifecycle definition. A status attribute without a lifecycle
    # means transitions are unconstrained, which often leads to invalid
    # state changes at runtime.
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     attribute :status, String
    #   end
    #
    # Would warn: "Order has a :status attribute but no lifecycle -- add a lifecycle DSL block"
    class MissingLifecycle < BaseRule
      STATUS_NAMES = %i[status state phase stage].freeze

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate that has a status-like attribute
      # but no lifecycle definition.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          has_status = agg.attributes.any? { |a| STATUS_NAMES.include?(a.name) }
          has_lifecycle = agg.respond_to?(:lifecycle) && agg.lifecycle
          if has_status && !has_lifecycle
            status_attr = agg.attributes.find { |a| STATUS_NAMES.include?(a.name) }
            result << error("#{agg.name} has a :#{status_attr.name} attribute but no lifecycle",
              hint: "Add: lifecycle :#{status_attr.name}, default: \"initial\" { transition \"Command\" => \"state\" }")
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(MissingLifecycle)
    end
  end
end

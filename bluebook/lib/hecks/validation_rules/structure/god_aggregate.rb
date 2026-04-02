module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::GodAggregate
    #
    # Advisory warning for aggregates that exhibit multiple "god object"
    # signals simultaneously: many attributes, many commands, and many
    # value objects. Any single signal is caught by its own rule, but
    # when multiple signals co-occur the aggregate is almost certainly
    # too large.
    #
    # Triggers when at least 2 of 3 thresholds are met:
    # - 6+ attributes
    # - 6+ commands
    # - 3+ value objects
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Megastore" do
    #     # 6 attributes, 6 commands, 3 value objects
    #   end
    #
    # Would warn: "Megastore is a god aggregate -- split by bounded context"
    class GodAggregate < BaseRule
      ATTR_THRESHOLD = 6
      CMD_THRESHOLD  = 6
      VO_THRESHOLD   = 3

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate that exceeds multiple
      # complexity thresholds simultaneously.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          signals = count_signals(agg)
          if signals >= 2
            result << error("#{agg.name} is a god aggregate (#{signals}/3 complexity signals exceeded)",
              hint: "Split into smaller aggregates organized by bounded context")
          end
        end
        result
      end

      private

      def count_signals(agg)
        vos = agg.respond_to?(:value_objects) ? agg.value_objects : []
        signals = 0
        signals += 1 if agg.attributes.size >= ATTR_THRESHOLD
        signals += 1 if agg.commands.size >= CMD_THRESHOLD
        signals += 1 if vos.size >= VO_THRESHOLD
        signals
      end
    end
    Hecks.register_validation_rule(GodAggregate)
    end
  end
end

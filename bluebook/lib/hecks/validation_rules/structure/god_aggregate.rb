module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::GodAggregate
    #
    # Advisory warning for aggregates that exceed all three thresholds
    # simultaneously: 8+ attributes, 8+ commands, and 3+ value objects.
    # An aggregate this large almost certainly violates the single
    # responsibility principle and should be decomposed into smaller
    # aggregates (Evans: Conceptual Contours).
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Monolith" do
    #     # 8 attributes, 8 commands, 3 value objects
    #   end
    #
    # Would warn: "Monolith is a god aggregate (8 attrs, 8 cmds, 3 VOs)
    #   -- strongly consider decomposing"
    class GodAggregate < BaseRule
      ATTR_THRESHOLD = 8
      CMD_THRESHOLD  = 8
      VO_THRESHOLD   = 3

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate that exceeds all three thresholds.
      #
      # @return [Array<String>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          attrs = agg.attributes.size
          cmds  = agg.commands.size
          vos   = agg.respond_to?(:value_objects) ? agg.value_objects.size : 0

          if attrs >= ATTR_THRESHOLD && cmds >= CMD_THRESHOLD && vos >= VO_THRESHOLD
            result << "#{agg.name} is a god aggregate (#{attrs} attrs, #{cmds} cmds, #{vos} VOs) -- strongly consider decomposing"
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(GodAggregate)
    end
  end
end

module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::CohesionAnalysis
    #
    # Advisory warning for aggregates where commands only touch a subset of
    # the aggregate's attributes. When most commands ignore most attributes,
    # the aggregate likely bundles unrelated concerns and should be split
    # (Evans: Conceptual Contours).
    #
    # Detection: for each aggregate, builds a set of attribute names referenced
    # across all commands. If fewer than half the root attributes appear in any
    # command, a low-cohesion warning fires.
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Order" do
    #     attribute :name, String
    #     attribute :address, String
    #     attribute :phone, String
    #     attribute :email, String
    #     command("PlaceOrder") { attribute :name, String }
    #   end
    #
    # Would warn: "Order has low cohesion -- commands touch 1/4 attributes"
    class CohesionAnalysis < BaseRule
      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each aggregate with low attribute-command
      # cohesion (fewer than half of root attributes appear in commands).
      #
      # @return [Array<String>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          next if agg.attributes.size < 3 || agg.commands.empty?

          root_names = agg.attributes.map { |a| a.name.to_s }.to_set
          command_attr_names = agg.commands.flat_map { |c|
            c.attributes.map { |a| a.name.to_s }
          }.to_set

          touched = (root_names & command_attr_names).size
          if touched < (root_names.size / 2.0).ceil
            result << "#{agg.name} has low cohesion -- commands touch #{touched}/#{root_names.size} attributes"
          end
        end
        result
      end
    end
    Hecks.register_validation_rule(CohesionAnalysis)
    end
  end
end

module Hecks
  module ValidationRules
    module Structure

    # Hecks::ValidationRules::Structure::CohesionAnalysis
    #
    # Advisory warning for aggregates where commands touch a disjoint
    # subset of attributes. Low cohesion suggests the aggregate may
    # contain unrelated concepts that should be split.
    #
    # Measures cohesion as the ratio of average command-attribute overlap
    # to total attributes. Warns when below THRESHOLD (0.3).
    #
    # Part of the ValidationRules::Structure group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "Account" do
    #     attribute :name, String
    #     attribute :balance, Integer
    #     attribute :email, String
    #     attribute :phone, String
    #     command "UpdateProfile" do attribute :name, String; attribute :email, String end
    #     command "Deposit" do attribute :balance, Integer end
    #   end
    #
    # Would warn: "Account has low cohesion (0.25) -- commands touch disjoint attribute sets"
    class CohesionAnalysis < BaseRule
      THRESHOLD = 0.3

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for aggregates with low command-attribute cohesion.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          next if agg.commands.size < 2
          next if agg.attributes.size < 3

          score = cohesion_score(agg)
          if score < THRESHOLD
            result << error(
              "#{agg.name} has low cohesion (#{"%.2f" % score}) -- commands touch disjoint attribute sets",
              hint: "Consider splitting into separate aggregates by attribute grouping"
            )
          end
        end
        result
      end

      private

      def cohesion_score(agg)
        agg_attr_names = agg.attributes.map { |a| a.name.to_s }.to_set
        return 1.0 if agg_attr_names.empty?

        overlaps = agg.commands.map do |cmd|
          cmd_attr_names = cmd.attributes.map { |a| a.name.to_s }.to_set
          (cmd_attr_names & agg_attr_names).size.to_f / agg_attr_names.size
        end

        overlaps.sum / overlaps.size
      end
    end
    Hecks.register_validation_rule(CohesionAnalysis)
    end
  end
end

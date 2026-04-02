module Hecks
  module ValidationRules
    module WorldGoals

      # Hecks::ValidationRules::WorldGoals::Sustainability
      #
      # When the :sustainability goal is declared, warns if any aggregate lacks a
      # lifecycle. Aggregates without lifecycles have no defined end state, which
      # means data may accumulate indefinitely with no archival or cleanup path.
      # This is advisory -- it never prevents validation from passing.
      #
      #   world_goals :sustainability
      #
      #   # warning: no lifecycle defined
      #   aggregate "Report" do
      #     attribute :title, String
      #     command "CreateReport" do
      #       attribute :title, String
      #     end
      #   end
      #
      class Sustainability < BaseRule
        def errors
          []
        end

        def warnings
          return [] unless @domain.world_goals.include?(:sustainability)

          issues = []
          @domain.aggregates.each do |agg|
            unless agg.lifecycle
              issues << "Sustainability: #{agg.name} has no lifecycle -- consider adding one for data retention and cleanup"
            end
          end
          issues
        end
      end
      Hecks.register_validation_rule(Sustainability)
    end
  end
end

module Hecks
  module ValidationRules
    module WorldConcerns

      # Hecks::ValidationRules::WorldConcerns::Equity
      #
      # When the :equity concern is declared, warns if the domain defines
      # only a single actor role. A single-role domain concentrates all
      # authority in one actor, which may create access inequities.
      #
      # This is always a warning, never an error -- it nudges the modeler
      # to consider whether additional roles are appropriate.
      #
      #   world_concerns :equity
      #
      #   actor "Admin"
      #   # warning: only one role defined -- consider adding more roles
      #
      class Equity < BaseRule
        def errors
          return [] unless @domain.world_concerns.include?(:equity)

          issues = []
          actor_names = @domain.actors.map(&:name).uniq
          if actor_names.size == 1
            issues << error(
              "Equity: only one actor role '#{actor_names.first}' defined",
              hint: "Consider adding additional roles to distribute authority"
            )
          end
          issues
        end
      end
      Hecks.register_validation_rule(Equity)
    end
  end
end

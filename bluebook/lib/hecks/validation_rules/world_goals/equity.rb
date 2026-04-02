module Hecks
  module ValidationRules
    module WorldGoals

      # Hecks::ValidationRules::WorldGoals::Equity
      #
      # When the :equity goal is declared, warns if the domain has only a single
      # actor role. A single-actor domain concentrates all authority in one role,
      # which may undermine equitable access. This is advisory -- it never
      # prevents validation from passing.
      #
      #   world_goals :equity
      #
      #   # warning: only one actor role defined
      #   actor "Admin"
      #
      #   # no warning: multiple roles provide checks and balances
      #   actor "Admin"
      #   actor "Reviewer"
      #
      class Equity < BaseRule
        def errors
          []
        end

        def warnings
          return [] unless @domain.world_goals.include?(:equity)

          issues = []
          if @domain.actors.size == 1
            role = @domain.actors.first.name
            issues << "Equity: only one actor role '#{role}' -- consider additional roles for equitable access"
          end
          issues
        end
      end
      Hecks.register_validation_rule(Equity)
    end
  end
end

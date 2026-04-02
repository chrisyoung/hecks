module Hecks
  module ValidationRules

    # Hecks::ValidationRules::WorldGoals
    #
    # Advisory validation rules activated by the +world_goals+ DSL keyword.
    # Unlike world_concerns (which produce errors), world goals produce only
    # warnings. Each rule checks a broad aspirational goal (equity,
    # sustainability) and only fires when its goal is declared on the domain.
    #
    # Rules are autoloaded and self-register via +Hecks.register_validation_rule+.
    #
    #   Hecks.domain "GovAI" do
    #     world_goals :equity, :sustainability
    #     # ... aggregates ...
    #   end
    #
    module WorldGoals
      autoload :Equity,         "hecks/validation_rules/world_goals/equity"
      autoload :Sustainability, "hecks/validation_rules/world_goals/sustainability"
    end
  end
end

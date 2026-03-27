module ModelRegistryDomain
  class AiModel
    module Queries
      class ByRiskLevel
        def call(level)
          where(risk_level: level)
        end
      end
    end
  end
end

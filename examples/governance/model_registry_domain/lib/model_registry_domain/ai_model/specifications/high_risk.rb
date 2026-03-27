module ModelRegistryDomain
  class AiModel
    module Specifications
      class HighRisk
        def satisfied_by?(model)
          model.risk_level == "high" || model.risk_level == "critical"
        end
      end
    end
  end
end

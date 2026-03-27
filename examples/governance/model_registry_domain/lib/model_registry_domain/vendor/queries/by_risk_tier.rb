module ModelRegistryDomain
  class Vendor
    module Queries
      class ByRiskTier
        def call(tier)
          where(risk_tier: tier)
        end
      end
    end
  end
end

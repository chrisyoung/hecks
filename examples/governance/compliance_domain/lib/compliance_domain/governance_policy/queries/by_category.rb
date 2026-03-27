module ComplianceDomain
  class GovernancePolicy
    module Queries
      class ByCategory
        def call(category)
          where(category: category)
        end
      end
    end
  end
end

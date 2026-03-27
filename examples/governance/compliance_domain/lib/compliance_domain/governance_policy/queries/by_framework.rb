module ComplianceDomain
  class GovernancePolicy
    module Queries
      class ByFramework
        def call(framework_id)
          where(framework_id: framework_id)
        end
      end
    end
  end
end

module ComplianceDomain
  class GovernancePolicy
    module Queries
      class Active
        def call
          where(status: "active")
        end
      end
    end
  end
end

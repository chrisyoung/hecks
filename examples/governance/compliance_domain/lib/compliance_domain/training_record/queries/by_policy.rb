module ComplianceDomain
  class TrainingRecord
    module Queries
      class ByPolicy
        def call(policy_id)
          where(policy_id: policy_id)
        end
      end
    end
  end
end

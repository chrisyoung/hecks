module ComplianceDomain
  class TrainingRecord
    module Queries
      class ByStakeholder
        def call(stakeholder_id)
          where(stakeholder_id: stakeholder_id)
        end
      end
    end
  end
end

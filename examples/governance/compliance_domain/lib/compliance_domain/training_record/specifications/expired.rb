module ComplianceDomain
  class TrainingRecord
    module Specifications
      class Expired
        def satisfied_by?(t)
          t.expires_at && t.expires_at.to_s < Date.today.to_s
        end
      end
    end
  end
end

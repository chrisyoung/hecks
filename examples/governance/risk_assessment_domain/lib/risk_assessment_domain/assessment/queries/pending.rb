module RiskAssessmentDomain
  class Assessment
    module Queries
      class Pending
        def call
          where(status: "pending")
        end
      end
    end
  end
end

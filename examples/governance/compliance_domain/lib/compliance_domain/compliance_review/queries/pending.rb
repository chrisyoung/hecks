module ComplianceDomain
  class ComplianceReview
    module Queries
      class Pending
        def call
          where(status: "open")
        end
      end
    end
  end
end

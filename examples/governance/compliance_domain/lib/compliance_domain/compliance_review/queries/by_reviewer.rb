module ComplianceDomain
  class ComplianceReview
    module Queries
      class ByReviewer
        def call(reviewer_id)
          where(reviewer_id: reviewer_id)
        end
      end
    end
  end
end

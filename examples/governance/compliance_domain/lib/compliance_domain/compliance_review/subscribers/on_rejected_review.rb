module ComplianceDomain
  class ComplianceReview
    module Subscribers
      class OnRejectedReview
        EVENT = "RejectedReview"
        ASYNC = false

        def self.event = EVENT
        def self.async = ASYNC

        def call(event)
          # Side-effect: notify model owner of rejection
        end
      end
    end
  end
end

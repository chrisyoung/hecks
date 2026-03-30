module ComplianceDomain
  class ComplianceReview
    module Commands
      class RejectReview
        include Hecks::Command
        emits "RejectedReview"

        attr_reader :review_id, :notes

        def initialize(review_id: nil, notes: nil)
          @review_id = review_id
          @notes = notes
        end

        def call
          existing = repository.find(review_id)
          if existing
            unless ["open", "changes_requested"].include?(existing.status)
              raise ComplianceDomain::Error, "Cannot RejectReview: status must be one of open, changes_requested, got '#{existing.status}'"
            end
            ComplianceReview.new(
              id: existing.id,
              model_id: existing.model_id,
              policy_id: existing.policy_id,
              reviewer_id: existing.reviewer_id,
              notes: notes,
              conditions: existing.conditions,
              outcome: "rejected",
              completed_at: Time.now.to_s,
              status: "rejected"
            )
          else
            raise ComplianceDomain::Error, "ComplianceReview not found: #{review_id}"
          end
        end
      end
    end
  end
end

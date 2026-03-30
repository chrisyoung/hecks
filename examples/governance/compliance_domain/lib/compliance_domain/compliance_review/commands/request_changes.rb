module ComplianceDomain
  class ComplianceReview
    module Commands
      class RequestChanges
        include Hecks::Command
        emits "RequestedChanges"

        attr_reader :review_id, :notes

        def initialize(review_id: nil, notes: nil)
          @review_id = review_id
          @notes = notes
        end

        def call
          existing = repository.find(review_id)
          if existing
            unless existing.status == "open"
              raise ComplianceDomain::Error, "Cannot RequestChanges: status must be 'open', got '#{existing.status}'"
            end
            ComplianceReview.new(
              id: existing.id,
              model_id: existing.model_id,
              policy_id: existing.policy_id,
              reviewer_id: existing.reviewer_id,
              outcome: existing.outcome,
              notes: notes,
              completed_at: existing.completed_at,
              conditions: existing.conditions,
              status: "changes_requested"
            )
          else
            raise ComplianceDomain::Error, "ComplianceReview not found: #{review_id}"
          end
        end
      end
    end
  end
end

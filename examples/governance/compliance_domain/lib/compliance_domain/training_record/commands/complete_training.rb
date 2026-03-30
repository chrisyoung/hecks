module ComplianceDomain
  class TrainingRecord
    module Commands
      class CompleteTraining
        include Hecks::Command
        emits "CompletedTraining"

        attr_reader :training_record_id
        attr_reader :certification
        attr_reader :expires_at

        def initialize(
          training_record_id: nil,
          certification: nil,
          expires_at: nil
        )
          @training_record_id = training_record_id
          @certification = certification
          @expires_at = expires_at
        end

        def call
          existing = repository.find(training_record_id)
          if existing
            unless existing.status == "assigned"
              raise ComplianceDomain::Error, "Cannot CompleteTraining: status must be 'assigned', got '#{existing.status}'"
            end
            TrainingRecord.new(
              id: existing.id,
              stakeholder_id: existing.stakeholder_id,
              policy_id: existing.policy_id,
              expires_at: expires_at,
              certification: certification,
              completed_at: Time.now.to_s,
              status: "completed"
            )
          else
            raise ComplianceDomain::Error, "TrainingRecord not found: #{training_record_id}"
          end
        end
      end
    end
  end
end

module ComplianceDomain
  class TrainingRecord
    module Commands
      class RenewTraining
        include Hecks::Command
        emits "RenewedTraining"

        attr_reader :training_record_id
        attr_reader :certification_id
        attr_reader :expires_at

        def initialize(
          training_record_id: nil,
          certification_id: nil,
          expires_at: nil
        )
          @training_record_id = training_record_id
          @certification_id = certification_id
          @expires_at = expires_at
        end

        def call
          existing = repository.find(training_record_id)
          if existing
            unless existing.status == "completed"
              raise Hecks::Error, "Cannot RenewTraining: status must be 'completed', got '#{existing.status}'"
            end
            TrainingRecord.new(
              id: existing.id,
              stakeholder_id: existing.stakeholder_id,
              policy_id: existing.policy_id,
              expires_at: expires_at,
              certification_id: certification_id,
              completed_at: Time.now.to_s,
              status: "completed"
            )
          else
            raise Hecks::Error, "TrainingRecord not found: #{training_record_id}"
          end
        end
      end
    end
  end
end

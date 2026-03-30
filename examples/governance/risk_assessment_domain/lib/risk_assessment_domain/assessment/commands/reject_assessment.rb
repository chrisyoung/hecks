module RiskAssessmentDomain
  class Assessment
    module Commands
      class RejectAssessment
        include Hecks::Command
        emits "RejectedAssessment"

        attr_reader :assessment_id

        def initialize(assessment_id: nil)
          @assessment_id = assessment_id
        end

        def call
          existing = repository.find(assessment_id)
          if existing
            unless ["pending", "submitted"].include?(existing.status)
              raise RiskAssessmentDomain::Error, "Cannot RejectAssessment: status must be one of pending, submitted, got '#{existing.status}'"
            end
            Assessment.new(
              id: existing.id,
              model_id: existing.model_id,
              assessor_id: existing.assessor_id,
              risk_level: existing.risk_level,
              bias_score: existing.bias_score,
              safety_score: existing.safety_score,
              transparency_score: existing.transparency_score,
              overall_score: existing.overall_score,
              submitted_at: existing.submitted_at,
              findings: existing.findings,
              mitigations: existing.mitigations,
              status: "rejected"
            )
          else
            raise RiskAssessmentDomain::Error, "Assessment not found: #{assessment_id}"
          end
        end
      end
    end
  end
end

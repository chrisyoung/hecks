module RiskAssessmentDomain
  class Assessment
    module Commands
      class SubmitAssessment
        include Hecks::Command
        emits "SubmittedAssessment"

        attr_reader :assessment_id
        attr_reader :risk_level
        attr_reader :bias_score
        attr_reader :safety_score
        attr_reader :transparency_score
        attr_reader :overall_score

        def initialize(
          assessment_id: nil,
          risk_level: nil,
          bias_score: nil,
          safety_score: nil,
          transparency_score: nil,
          overall_score: nil
        )
          @assessment_id = assessment_id
          @risk_level = risk_level
          @bias_score = bias_score
          @safety_score = safety_score
          @transparency_score = transparency_score
          @overall_score = overall_score
        end

        def call
          existing = repository.find(assessment_id)
          if existing
            unless existing.status == "pending"
              raise Hecks::Error, "Cannot SubmitAssessment: status must be 'pending', got '#{existing.status}'"
            end
            Assessment.new(
              id: existing.id,
              model_id: existing.model_id,
              assessor_id: existing.assessor_id,
              risk_level: risk_level,
              bias_score: bias_score,
              safety_score: safety_score,
              transparency_score: transparency_score,
              overall_score: overall_score,
              findings: existing.findings,
              mitigations: existing.mitigations,
              submitted_at: Time.now.to_s,
              status: "submitted"
            )
          else
            raise Hecks::Error, "Assessment not found: #{assessment_id}"
          end
        end
      end
    end
  end
end

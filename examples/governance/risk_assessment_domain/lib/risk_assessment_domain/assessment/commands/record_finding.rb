module RiskAssessmentDomain
  class Assessment
    module Commands
      class RecordFinding
        include Hecks::Command
        emits "RecordedFinding"

        attr_reader :assessment_id
        attr_reader :category
        attr_reader :severity
        attr_reader :description

        def initialize(
          assessment_id: nil,
          category: nil,
          severity: nil,
          description: nil
        )
          @assessment_id = assessment_id
          @category = category
          @severity = severity
          @description = description
        end

        def call
          existing = repository.find(assessment_id)
          if existing
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
              status: existing.status
            )
          else
            raise Hecks::Error, "Assessment not found: #{assessment_id}"
          end
        end
      end
    end
  end
end

module RiskAssessmentDomain
  class Assessment
    module Events
      class RejectedAssessment
        attr_reader :aggregate_id, :assessment_id, :model_id, :assessor_id, :risk_level, :bias_score, :safety_score, :transparency_score, :overall_score, :submitted_at, :findings, :mitigations, :status, :occurred_at

        def initialize(aggregate_id: nil, assessment_id: nil, model_id: nil, assessor_id: nil, risk_level: nil, bias_score: nil, safety_score: nil, transparency_score: nil, overall_score: nil, submitted_at: nil, findings: nil, mitigations: nil, status: nil)
          @aggregate_id = aggregate_id
          @assessment_id = assessment_id
          @model_id = model_id
          @assessor_id = assessor_id
          @risk_level = risk_level
          @bias_score = bias_score
          @safety_score = safety_score
          @transparency_score = transparency_score
          @overall_score = overall_score
          @submitted_at = submitted_at
          @findings = findings
          @mitigations = mitigations
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

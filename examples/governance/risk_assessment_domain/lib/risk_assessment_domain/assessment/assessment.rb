require 'hecks/model'

module RiskAssessmentDomain
  class Assessment
    autoload :Finding, "risk_assessment_domain/assessment/finding"
    autoload :Mitigation, "risk_assessment_domain/assessment/mitigation"
    autoload :Lifecycle, "risk_assessment_domain/assessment/lifecycle"

    include Hecks::Model

    attribute :model_id
    attribute :assessor_id
    attribute :risk_level
    attribute :bias_score
    attribute :safety_score
    attribute :transparency_score
    attribute :overall_score
    attribute :submitted_at
    attribute :findings, default: [], freeze: true
    attribute :mitigations, default: [], freeze: true
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def pending?; status == "pending"; end
    def submitted?; status == "submitted"; end
    def rejected?; status == "rejected"; end

    VALID_RISK_LEVEL = ["low", "medium", "high", "critical"].freeze unless defined?(VALID_RISK_LEVEL)

    private

    def validate!
      raise ValidationError, "model_id can't be blank" if model_id.nil? || (model_id.respond_to?(:empty?) && model_id.empty?)
      raise ValidationError, "assessor_id can't be blank" if assessor_id.nil? || (assessor_id.respond_to?(:empty?) && assessor_id.empty?)
      if risk_level && !VALID_RISK_LEVEL.include?(risk_level)
        raise ValidationError, "risk_level must be one of: #{VALID_RISK_LEVEL.join(', ')}, got: #{risk_level}"
      end
    end

    def check_invariants!
      raise InvariantError, "scores must be between 0 and 1" unless instance_eval(&proc { [bias_score, safety_score, transparency_score, overall_score].all? { |s|
s.nil? || (s >= 0.0 && s <= 1.0)
} })
    end
  end
end

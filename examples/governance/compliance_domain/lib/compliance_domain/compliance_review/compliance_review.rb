require 'hecks/mixins/model'

module ComplianceDomain
  class ComplianceReview
    autoload :ReviewCondition, "compliance_domain/compliance_review/review_condition"
    autoload :Lifecycle, "compliance_domain/compliance_review/lifecycle"

    include Hecks::Model

    attribute :model_id
    attribute :policy_id
    attribute :reviewer_id
    attribute :outcome
    attribute :notes
    attribute :completed_at
    attribute :conditions, default: [], freeze: true
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def open?; status == "open"; end
    def approved?; status == "approved"; end
    def rejected?; status == "rejected"; end
    def changes_requested?; status == "changes_requested"; end

    VALID_OUTCOME = ["approved", "rejected"].freeze unless defined?(VALID_OUTCOME)

    private

    def validate!
      raise ValidationError.new("model_id can't be blank", field: :model_id, rule: :presence) if model_id.nil? || (model_id.respond_to?(:empty?) && model_id.empty?)
      raise ValidationError.new("reviewer_id can't be blank", field: :reviewer_id, rule: :presence) if reviewer_id.nil? || (reviewer_id.respond_to?(:empty?) && reviewer_id.empty?)
      if outcome && !VALID_OUTCOME.include?(outcome)
        raise ValidationError, "outcome must be one of: #{VALID_OUTCOME.join(', ')}, got: #{outcome}"
      end
    end
  end
end

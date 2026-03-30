require 'hecks/mixins/model'

module ComplianceDomain
  class TrainingRecord
    autoload :Lifecycle, "compliance_domain/training_record/lifecycle"

    include Hecks::Model

    attribute :stakeholder_id
    attribute :policy_id
    attribute :completed_at
    attribute :expires_at
    attribute :certification
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def assigned?; status == "assigned"; end
    def completed?; status == "completed"; end

    private

    def validate!
      raise ValidationError.new("stakeholder_id can't be blank", field: :stakeholder_id, rule: :presence) if stakeholder_id.nil? || (stakeholder_id.respond_to?(:empty?) && stakeholder_id.empty?)
      raise ValidationError.new("policy_id can't be blank", field: :policy_id, rule: :presence) if policy_id.nil? || (policy_id.respond_to?(:empty?) && policy_id.empty?)
    end

    def check_invariants!
      raise InvariantError, "expires_at must be after completed_at" unless instance_eval(&proc { !expires_at || !completed_at || expires_at.to_s >= completed_at.to_s[0, 10] })
    end
  end
end

require 'hecks/model'

module ComplianceDomain
  class Exemption
    autoload :Lifecycle, "compliance_domain/exemption/lifecycle"

    include Hecks::Model

    attribute :model_id
    attribute :policy_id
    attribute :requirement
    attribute :reason
    attribute :approved_by_id
    attribute :approved_at
    attribute :expires_at
    attribute :scope
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def requested?; status == "requested"; end
    def active?; status == "active"; end
    def revoked?; status == "revoked"; end

    private

    def validate!
      raise ValidationError, "model_id can't be blank" if model_id.nil? || (model_id.respond_to?(:empty?) && model_id.empty?)
      raise ValidationError, "policy_id can't be blank" if policy_id.nil? || (policy_id.respond_to?(:empty?) && policy_id.empty?)
    end
  end
end

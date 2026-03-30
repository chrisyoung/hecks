require 'hecks/mixins/model'

module IdentityDomain
  class Stakeholder
    autoload :Lifecycle, "identity_domain/stakeholder/lifecycle"

    include Hecks::Model

    attribute :name
    attribute :email
    attribute :role
    attribute :team
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def active?; status == "active"; end
    def deactivated?; status == "deactivated"; end

    VALID_ROLE = ["assessor", "reviewer", "governance_board", "data_steward", "incident_reporter", "admin", "auditor"].freeze unless defined?(VALID_ROLE)

    private

    def validate!
      raise ValidationError.new("name can't be blank", field: :name, rule: :presence) if name.nil? || (name.respond_to?(:empty?) && name.empty?)
      raise ValidationError.new("email can't be blank", field: :email, rule: :presence) if email.nil? || (email.respond_to?(:empty?) && email.empty?)
      if role && !VALID_ROLE.include?(role)
        raise ValidationError, "role must be one of: #{VALID_ROLE.join(', ')}, got: #{role}"
      end
    end
  end
end

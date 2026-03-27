require 'hecks/model'

module ModelRegistryDomain
  class DataUsageAgreement
    autoload :Restriction, "model_registry_domain/data_usage_agreement/restriction"
    autoload :Lifecycle, "model_registry_domain/data_usage_agreement/lifecycle"

    include Hecks::Model

    attribute :model_id
    attribute :data_source
    attribute :purpose
    attribute :consent_type
    attribute :effective_date
    attribute :expiration_date
    attribute :restrictions, default: [], freeze: true
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def draft?; status == "draft"; end
    def active?; status == "active"; end
    def revoked?; status == "revoked"; end

    VALID_CONSENT_TYPE = ["public_domain", "CC-BY-SA", "licensed", "consent", "opt-out"].freeze unless defined?(VALID_CONSENT_TYPE)

    private

    def validate!
      raise ValidationError, "data_source can't be blank" if data_source.nil? || (data_source.respond_to?(:empty?) && data_source.empty?)
      raise ValidationError, "purpose can't be blank" if purpose.nil? || (purpose.respond_to?(:empty?) && purpose.empty?)
      if consent_type && !VALID_CONSENT_TYPE.include?(consent_type)
        raise ValidationError, "consent_type must be one of: #{VALID_CONSENT_TYPE.join(', ')}, got: #{consent_type}"
      end
    end

    def check_invariants!
      raise InvariantError, "expiration must be after effective date" unless instance_eval(&proc { !expiration_date || !effective_date || expiration_date.to_s >= effective_date.to_s })
    end
  end
end

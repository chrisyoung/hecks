require 'hecks/mixins/model'

module ModelRegistryDomain
  class Vendor
    autoload :Lifecycle, "model_registry_domain/vendor/lifecycle"

    include Hecks::Model

    attribute :name
    attribute :contact_email
    attribute :risk_tier
    attribute :assessment_date
    attribute :next_review_date
    attribute :sla_terms
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def pending_review?; status == "pending_review"; end
    def approved?; status == "approved"; end
    def suspended?; status == "suspended"; end

    VALID_RISK_TIER = ["low", "medium", "high"].freeze unless defined?(VALID_RISK_TIER)

    private

    def validate!
      raise ValidationError.new("name can't be blank", field: :name, rule: :presence) if name.nil? || (name.respond_to?(:empty?) && name.empty?)
      if risk_tier && !VALID_RISK_TIER.include?(risk_tier)
        raise ValidationError, "risk_tier must be one of: #{VALID_RISK_TIER.join(', ')}, got: #{risk_tier}"
      end
    end
  end
end

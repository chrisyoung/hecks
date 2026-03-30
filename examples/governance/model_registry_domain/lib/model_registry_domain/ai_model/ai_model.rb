require 'hecks/mixins/model'

module ModelRegistryDomain
  class AiModel
    autoload :Capability, "model_registry_domain/ai_model/capability"
    autoload :IntendedUse, "model_registry_domain/ai_model/intended_use"
    autoload :Lifecycle, "model_registry_domain/ai_model/lifecycle"

    include Hecks::Model

    attribute :name
    attribute :version
    attribute :provider_id
    attribute :description
    attribute :risk_level
    attribute :registered_at
    attribute :parent_model_id
    attribute :derivation_type
    attribute :capabilities, default: [], freeze: true
    attribute :intended_uses, default: [], freeze: true
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def draft?; status == "draft"; end
    def classified?; status == "classified"; end
    def approved?; status == "approved"; end
    def suspended?; status == "suspended"; end
    def retired?; status == "retired"; end

    VALID_RISK_LEVEL = ["low", "medium", "high", "critical"].freeze unless defined?(VALID_RISK_LEVEL)
    VALID_DERIVATION_TYPE = ["fine-tuned", "distilled", "retrained", "quantized"].freeze unless defined?(VALID_DERIVATION_TYPE)

    private

    def validate!
      raise ValidationError.new("name can't be blank", field: :name, rule: :presence) if name.nil? || (name.respond_to?(:empty?) && name.empty?)
      raise ValidationError.new("version can't be blank", field: :version, rule: :presence) if version.nil? || (version.respond_to?(:empty?) && version.empty?)
      if risk_level && !VALID_RISK_LEVEL.include?(risk_level)
        raise ValidationError, "risk_level must be one of: #{VALID_RISK_LEVEL.join(', ')}, got: #{risk_level}"
      end
      if derivation_type && !VALID_DERIVATION_TYPE.include?(derivation_type)
        raise ValidationError, "derivation_type must be one of: #{VALID_DERIVATION_TYPE.join(', ')}, got: #{derivation_type}"
      end
    end
  end
end

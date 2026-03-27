module ModelRegistryDomain
  class AiModel
    module Events
      class DerivedModel
        attr_reader :aggregate_id, :name, :version, :parent_model_id, :derivation_type, :description, :provider_id, :risk_level, :registered_at, :capabilities, :intended_uses, :status, :occurred_at

        def initialize(aggregate_id: nil, name: nil, version: nil, parent_model_id: nil, derivation_type: nil, description: nil, provider_id: nil, risk_level: nil, registered_at: nil, capabilities: nil, intended_uses: nil, status: nil)
          @aggregate_id = aggregate_id
          @name = name
          @version = version
          @parent_model_id = parent_model_id
          @derivation_type = derivation_type
          @description = description
          @provider_id = provider_id
          @risk_level = risk_level
          @registered_at = registered_at
          @capabilities = capabilities
          @intended_uses = intended_uses
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

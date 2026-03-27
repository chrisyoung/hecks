module ModelRegistryDomain
  class AiModel
    module Events
      class ApprovedModel
        attr_reader :aggregate_id, :model_id, :name, :version, :provider_id, :description, :risk_level, :registered_at, :parent_model_id, :derivation_type, :capabilities, :intended_uses, :status, :occurred_at

        def initialize(aggregate_id: nil, model_id: nil, name: nil, version: nil, provider_id: nil, description: nil, risk_level: nil, registered_at: nil, parent_model_id: nil, derivation_type: nil, capabilities: nil, intended_uses: nil, status: nil)
          @aggregate_id = aggregate_id
          @model_id = model_id
          @name = name
          @version = version
          @provider_id = provider_id
          @description = description
          @risk_level = risk_level
          @registered_at = registered_at
          @parent_model_id = parent_model_id
          @derivation_type = derivation_type
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

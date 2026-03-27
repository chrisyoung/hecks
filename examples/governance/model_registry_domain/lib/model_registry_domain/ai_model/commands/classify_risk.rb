module ModelRegistryDomain
  class AiModel
    module Commands
      class ClassifyRisk
        include Hecks::Command
        emits "ClassifiedRisk"

        attr_reader :model_id, :risk_level

        def initialize(model_id: nil, risk_level: nil)
          @model_id = model_id
          @risk_level = risk_level
        end

        def call
          existing = repository.find(model_id)
          if existing
            unless existing.status == "draft"
              raise Hecks::Error, "Cannot ClassifyRisk: status must be 'draft', got '#{existing.status}'"
            end
            AiModel.new(
              id: existing.id,
              name: existing.name,
              version: existing.version,
              provider_id: existing.provider_id,
              description: existing.description,
              registered_at: existing.registered_at,
              parent_model_id: existing.parent_model_id,
              derivation_type: existing.derivation_type,
              capabilities: existing.capabilities,
              intended_uses: existing.intended_uses,
              risk_level: risk_level,
              status: "classified"
            )
          else
            raise Hecks::Error, "AiModel not found: #{model_id}"
          end
        end
      end
    end
  end
end

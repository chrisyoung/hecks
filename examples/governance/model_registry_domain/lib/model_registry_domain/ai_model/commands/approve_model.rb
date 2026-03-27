module ModelRegistryDomain
  class AiModel
    module Commands
      class ApproveModel
        include Hecks::Command
        emits "ApprovedModel"

        attr_reader :model_id

        def initialize(model_id: nil)
          @model_id = model_id
        end

        def call
          existing = repository.find(model_id)
          if existing
            unless existing.status == "classified"
              raise Hecks::Error, "Cannot ApproveModel: status must be 'classified', got '#{existing.status}'"
            end
            AiModel.new(
              id: existing.id,
              name: existing.name,
              version: existing.version,
              provider_id: existing.provider_id,
              description: existing.description,
              risk_level: existing.risk_level,
              registered_at: existing.registered_at,
              parent_model_id: existing.parent_model_id,
              derivation_type: existing.derivation_type,
              capabilities: existing.capabilities,
              intended_uses: existing.intended_uses,
              status: "approved"
            )
          else
            raise Hecks::Error, "AiModel not found: #{model_id}"
          end
        end
      end
    end
  end
end

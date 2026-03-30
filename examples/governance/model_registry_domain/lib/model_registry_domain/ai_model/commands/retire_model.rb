module ModelRegistryDomain
  class AiModel
    module Commands
      class RetireModel
        include Hecks::Command
        emits "RetiredModel"

        attr_reader :model_id

        def initialize(model_id: nil)
          @model_id = model_id
        end

        def call
          existing = repository.find(model_id)
          if existing
            unless ["approved", "suspended"].include?(existing.status)
              raise ModelRegistryDomain::Error, "Cannot RetireModel: status must be one of approved, suspended, got '#{existing.status}'"
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
              status: "retired"
            )
          else
            raise ModelRegistryDomain::Error, "AiModel not found: #{model_id}"
          end
        end
      end
    end
  end
end

module ModelRegistryDomain
  class AiModel
    module Commands
      class DeriveModel
        include Hecks::Command
        emits "DerivedModel"

        attr_reader :name
        attr_reader :version
        attr_reader :parent_model_id
        attr_reader :derivation_type
        attr_reader :description

        def initialize(
          name: nil,
          version: nil,
          parent_model_id: nil,
          derivation_type: nil,
          description: nil
        )
          @name = name
          @version = version
          @parent_model_id = parent_model_id
          @derivation_type = derivation_type
          @description = description
        end

        def call
          AiModel.new(
            name: name,
            version: version,
            description: description,
            parent_model_id: parent_model_id,
            derivation_type: derivation_type,
            registered_at: Time.now.to_s,
            status: "draft"
          )
        end
      end
    end
  end
end

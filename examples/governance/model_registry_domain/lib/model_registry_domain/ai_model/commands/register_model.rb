module ModelRegistryDomain
  class AiModel
    module Commands
      class RegisterModel
        include Hecks::Command
        emits "RegisteredModel"

        attr_reader :name
        attr_reader :version
        attr_reader :provider_id
        attr_reader :description

        def initialize(
          name: nil,
          version: nil,
          provider_id: nil,
          description: nil
        )
          @name = name
          @version = version
          @provider_id = provider_id
          @description = description
        end

        def call
          AiModel.new(
            name: name,
            version: version,
            provider_id: provider_id,
            description: description,
            registered_at: Time.now.to_s,
            status: "draft"
          )
        end
      end
    end
  end
end

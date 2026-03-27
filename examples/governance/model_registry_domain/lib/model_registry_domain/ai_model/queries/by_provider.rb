module ModelRegistryDomain
  class AiModel
    module Queries
      class ByProvider
        def call(provider_id)
          where(provider_id: provider_id)
        end
      end
    end
  end
end

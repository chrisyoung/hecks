module ModelRegistryDomain
  class AiModel
    module Queries
      class ByParent
        def call(parent_id)
          where(parent_model_id: parent_id)
        end
      end
    end
  end
end

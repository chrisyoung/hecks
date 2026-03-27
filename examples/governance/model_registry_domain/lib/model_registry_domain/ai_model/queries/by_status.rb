module ModelRegistryDomain
  class AiModel
    module Queries
      class ByStatus
        def call(status)
          where(status: status)
        end
      end
    end
  end
end

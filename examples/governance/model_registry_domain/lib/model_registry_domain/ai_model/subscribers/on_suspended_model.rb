module ModelRegistryDomain
  class AiModel
    module Subscribers
      class OnSuspendedModel
        EVENT = "SuspendedModel"
        ASYNC = false

        def self.event = EVENT
        def self.async = ASYNC

        def call(event)
          # Side-effect: notify vendor when their model is suspended
        end
      end
    end
  end
end

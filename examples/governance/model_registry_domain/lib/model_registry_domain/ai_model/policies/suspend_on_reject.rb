module ModelRegistryDomain
  class AiModel
    module Policies
      class SuspendOnReject
        EVENT   = "RejectedReview"
        TRIGGER = "SuspendModel"
        ASYNC   = false
        MAP     = {:model_id=>:model_id}.freeze

        def self.event   = EVENT
        def self.trigger = TRIGGER
        def self.async   = ASYNC

        attr_reader :result

        def call(event)
          # Maps event attrs and dispatches trigger command
          self
        end
      end
    end
  end
end

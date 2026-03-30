module OperationsDomain
  class Monitoring
    module Commands
      class SetThreshold
        include Hecks::Command
        emits "SetThreshold"

        attr_reader :monitoring_id, :threshold

        def initialize(monitoring_id: nil, threshold: nil)
          @monitoring_id = monitoring_id
          @threshold = threshold
        end

        def call
          existing = repository.find(monitoring_id)
          if existing
            Monitoring.new(
              id: existing.id,
              model_id: existing.model_id,
              deployment_id: existing.deployment_id,
              metric_name: existing.metric_name,
              value: existing.value,
              recorded_at: existing.recorded_at,
              threshold: threshold
            )
          else
            raise OperationsDomain::Error, "Monitoring not found: #{monitoring_id}"
          end
        end
      end
    end
  end
end

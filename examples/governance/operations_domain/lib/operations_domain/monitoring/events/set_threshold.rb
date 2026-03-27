module OperationsDomain
  class Monitoring
    module Events
      class SetThreshold
        attr_reader :aggregate_id, :monitoring_id, :threshold, :model_id, :deployment_id, :metric_name, :value, :recorded_at, :occurred_at

        def initialize(aggregate_id: nil, monitoring_id: nil, threshold: nil, model_id: nil, deployment_id: nil, metric_name: nil, value: nil, recorded_at: nil)
          @aggregate_id = aggregate_id
          @monitoring_id = monitoring_id
          @threshold = threshold
          @model_id = model_id
          @deployment_id = deployment_id
          @metric_name = metric_name
          @value = value
          @recorded_at = recorded_at
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

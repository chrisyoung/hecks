module OperationsDomain
  class Monitoring
    module Events
      class RecordedMetric
        attr_reader :aggregate_id, :model_id, :deployment_id, :metric_name, :value, :threshold, :recorded_at, :occurred_at

        def initialize(aggregate_id: nil, model_id: nil, deployment_id: nil, metric_name: nil, value: nil, threshold: nil, recorded_at: nil)
          @aggregate_id = aggregate_id
          @model_id = model_id
          @deployment_id = deployment_id
          @metric_name = metric_name
          @value = value
          @threshold = threshold
          @recorded_at = recorded_at
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

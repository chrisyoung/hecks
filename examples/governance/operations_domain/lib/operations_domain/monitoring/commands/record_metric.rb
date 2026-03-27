module OperationsDomain
  class Monitoring
    module Commands
      class RecordMetric
        include Hecks::Command
        emits "RecordedMetric"

        attr_reader :model_id
        attr_reader :deployment_id
        attr_reader :metric_name
        attr_reader :value
        attr_reader :threshold

        def initialize(
          model_id: nil,
          deployment_id: nil,
          metric_name: nil,
          value: nil,
          threshold: nil
        )
          @model_id = model_id
          @deployment_id = deployment_id
          @metric_name = metric_name
          @value = value
          @threshold = threshold
        end

        def call
          Monitoring.new(
            model_id: model_id,
            deployment_id: deployment_id,
            metric_name: metric_name,
            value: value,
            threshold: threshold,
            recorded_at: Time.now.to_s
          )
        end
      end
    end
  end
end

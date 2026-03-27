require 'hecks/model'

module OperationsDomain
  class Monitoring
    include Hecks::Model

    attribute :model_id
    attribute :deployment_id
    attribute :metric_name
    attribute :value
    attribute :threshold
    attribute :recorded_at

    private

    def validate!
      raise ValidationError, "model_id can't be blank" if model_id.nil? || (model_id.respond_to?(:empty?) && model_id.empty?)
      raise ValidationError, "metric_name can't be blank" if metric_name.nil? || (metric_name.respond_to?(:empty?) && metric_name.empty?)
    end

    def check_invariants!
      raise InvariantError, "threshold must be positive" unless instance_eval(&proc { !threshold || threshold > 0 })
    end
  end
end

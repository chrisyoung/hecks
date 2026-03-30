require 'hecks/mixins/model'

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
      raise ValidationError.new("model_id can't be blank", field: :model_id, rule: :presence) if model_id.nil? || (model_id.respond_to?(:empty?) && model_id.empty?)
      raise ValidationError.new("metric_name can't be blank", field: :metric_name, rule: :presence) if metric_name.nil? || (metric_name.respond_to?(:empty?) && metric_name.empty?)
    end

    def check_invariants!
      raise InvariantError, "threshold must be positive" unless instance_eval(&proc { !threshold || threshold > 0 })
    end
  end
end

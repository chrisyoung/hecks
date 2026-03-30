require 'hecks/mixins/model'

module OperationsDomain
  class Incident
    autoload :Lifecycle, "operations_domain/incident/lifecycle"

    include Hecks::Model

    attribute :model_id
    attribute :severity
    attribute :category
    attribute :description
    attribute :reported_by_id
    attribute :reported_at
    attribute :resolved_at
    attribute :resolution
    attribute :root_cause
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def reported?; status == "reported"; end
    def investigating?; status == "investigating"; end
    def mitigating?; status == "mitigating"; end
    def resolved?; status == "resolved"; end
    def closed?; status == "closed"; end

    VALID_SEVERITY = ["low", "medium", "high", "critical"].freeze unless defined?(VALID_SEVERITY)
    VALID_CATEGORY = ["bias", "safety", "privacy", "performance", "other"].freeze unless defined?(VALID_CATEGORY)

    private

    def validate!
      raise ValidationError.new("model_id can't be blank", field: :model_id, rule: :presence) if model_id.nil? || (model_id.respond_to?(:empty?) && model_id.empty?)
      raise ValidationError.new("severity can't be blank", field: :severity, rule: :presence) if severity.nil? || (severity.respond_to?(:empty?) && severity.empty?)
      if severity && !VALID_SEVERITY.include?(severity)
        raise ValidationError, "severity must be one of: #{VALID_SEVERITY.join(', ')}, got: #{severity}"
      end
      if category && !VALID_CATEGORY.include?(category)
        raise ValidationError, "category must be one of: #{VALID_CATEGORY.join(', ')}, got: #{category}"
      end
    end
  end
end

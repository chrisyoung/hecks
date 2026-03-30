require 'hecks/mixins/model'

module OperationsDomain
  class Deployment
    autoload :Lifecycle, "operations_domain/deployment/lifecycle"

    include Hecks::Model

    attribute :model_id
    attribute :environment
    attribute :endpoint
    attribute :purpose
    attribute :audience
    attribute :deployed_at
    attribute :decommissioned_at
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def planned?; status == "planned"; end
    def deployed?; status == "deployed"; end
    def decommissioned?; status == "decommissioned"; end

    VALID_ENVIRONMENT = ["development", "staging", "production"].freeze unless defined?(VALID_ENVIRONMENT)
    VALID_AUDIENCE = ["internal", "customer-facing", "public"].freeze unless defined?(VALID_AUDIENCE)

    private

    def validate!
      raise ValidationError.new("model_id can't be blank", field: :model_id, rule: :presence) if model_id.nil? || (model_id.respond_to?(:empty?) && model_id.empty?)
      raise ValidationError.new("environment can't be blank", field: :environment, rule: :presence) if environment.nil? || (environment.respond_to?(:empty?) && environment.empty?)
      if environment && !VALID_ENVIRONMENT.include?(environment)
        raise ValidationError, "environment must be one of: #{VALID_ENVIRONMENT.join(', ')}, got: #{environment}"
      end
      if audience && !VALID_AUDIENCE.include?(audience)
        raise ValidationError, "audience must be one of: #{VALID_AUDIENCE.join(', ')}, got: #{audience}"
      end
    end
  end
end

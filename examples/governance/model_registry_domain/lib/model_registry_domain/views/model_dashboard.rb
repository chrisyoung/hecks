module ModelRegistryDomain
  module Views
    class ModelDashboard
      PROJECTIONS = %w[RegisteredModel ClassifiedRisk SuspendedModel].freeze unless defined?(PROJECTIONS)

      attr_reader :state

      def call(event, state = {})
        name = event.class.name.split('::').last
        method = :"project_#{domain_snake_name(name)}"
        @state = respond_to?(method) ? send(method, event, state) : state
        self
      end

      def project_registered_model(event, state)
        state.merge(total_models: (state[:total_models] || 0) + 1)
      end

      def project_classified_risk(event, state)
        risk = event.respond_to?(:risk_level) ? event.risk_level : "unknown"
by_risk = state[:models_by_risk] || {}
state.merge(models_by_risk: by_risk.merge(risk => (by_risk[risk] || 0) + 1))
      end

      def project_suspended_model(event, state)
        state.merge(suspended_count: (state[:suspended_count] || 0) + 1)
      end
    end
  end
end

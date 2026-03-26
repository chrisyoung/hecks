# Hecks::CrossDomainQuery
#
# A read-only query that spans multiple bounded contexts. Registered at
# the application level via Hecks.cross_domain_query, it resolves
# aggregate classes from any booted domain using the `from` helper.
#
#   Hecks.cross_domain_query "ComplianceCheck" do |model_id:|
#     model   = from("ModelRegistry", "AiModel").find(model_id)
#     reviews = from("Compliance", "ComplianceReview").by_model(model_id)
#     { model: model, reviews: reviews }
#   end
#
#   result = Hecks.query("ComplianceCheck", model_id: "abc")
#
module Hecks
  class CrossDomainQuery
    attr_reader :name

    def initialize(name, &block)
      @name = name
      @block = block
    end

    def call(**params)
      context = QueryContext.new
      context.instance_exec(**params, &@block)
    end

    # Execution context that provides the `from` helper for resolving
    # aggregate classes across domain boundaries.
    class QueryContext
      def from(domain_name, aggregate_name)
        mod_name = Hecks::Utils.sanitize_constant(domain_name) + "Domain"
        agg_name = Hecks::Utils.sanitize_constant(aggregate_name)
        Object.const_get("#{mod_name}::#{agg_name}")
      end
    end
  end
end

# Hecks::DomainBuilderMethods
#
# DSL entry points for defining, validating, and previewing domains.
#
#   Hecks.domain("Pizzas") { ... }
#   Hecks.validate(domain)
#   Hecks.preview(domain, "Pizza")
#   Hecks.session("Pizzas")
#
module Hecks
  module DomainBuilderMethods
    def domain(name, &block)
      builder = DSL::DomainBuilder.new(name)
      builder.instance_eval(&block)
      result = builder.build
      Hecks.last_domain = result
      result
    end

    def session(name)
      Session.new(name)
    end

    def validate(domain)
      validator = Validator.new(domain)
      [validator.valid?, validator.errors]
    end

    def preview(domain, aggregate_name)
      mod = domain.module_name + "Domain"
      agg = domain.aggregates.find { |a| a.name == aggregate_name }
      raise "Unknown aggregate: #{aggregate_name}" unless agg
      Generators::Domain::AggregateGenerator.new(agg, domain_module: mod).generate
    end
  end
end

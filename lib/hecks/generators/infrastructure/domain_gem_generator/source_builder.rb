# Hecks::Generators::Infrastructure::DomainGemGenerator::SourceBuilder
#
# Generates all domain Ruby source as one eval-ready string (no file I/O).
# Used by Hecks.load_domain for fast in-memory domain loading.
#
module Hecks
  module Generators
    module Infrastructure
      class DomainGemGenerator
        module SourceBuilder
          AGGREGATE_GENERATORS = {
            value_objects: Domain::ValueObjectGenerator,
            commands:      Domain::CommandGenerator,
            events:        Domain::EventGenerator,
            policies:      Domain::PolicyGenerator,
          }.freeze

          def generate_source
            mod = @domain.module_name + "Domain"
            [module_shell(mod), *aggregate_sources(mod)].join("\n")
          end

          private

          def module_shell(mod)
            "require 'securerandom'\nmodule #{mod}\n  class ValidationError < StandardError; end\n  class InvariantError < StandardError; end\nend"
          end

          def aggregate_sources(mod)
            parts = []
            @domain.aggregates.each do |agg|
              safe_name = Hecks::Utils.sanitize_constant(agg.name)
              opts = { domain_module: mod }
              parts << source_for(Domain::AggregateGenerator, agg, **opts)
              AGGREGATE_GENERATORS.each do |method, gen|
                agg.send(method).each { |obj| parts << source_for(gen, obj, aggregate_name: safe_name, **opts) }
              end
              parts << source_for(Infrastructure::PortGenerator, agg, **opts)
              parts << source_for(Infrastructure::MemoryAdapterGenerator, agg, **opts)
            end
            parts
          end

          def source_for(klass, obj, **opts) = klass.new(obj, **opts).generate
        end
      end
    end
  end
end

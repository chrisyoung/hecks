# Hecks::Generators::Infrastructure::DomainGemGenerator::SourceBuilder
#
# Mixin that generates all domain Ruby source as one eval-ready string (no
# file I/O). Produces aggregates, value objects, commands, events, policies,
# ports, and adapters. Injects Hecks::Command and Hecks::Query includes for
# eval-based loading since const_missing auto-include does not fire. Part of
# DomainGemGenerator, consumed by Hecks.load_domain.
#
#   gen = DomainGemGenerator.new(domain)
#   gen.generate_source  # => "require 'securerandom'\n..."
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
            subscribers:   Domain::SubscriberGenerator,
          }.freeze

          def generate_source
            mod = @domain.module_name + "Domain"
            [module_shell(mod), *aggregate_sources(mod)].join("\n")
          end

          private

          def module_shell(mod)
            "require 'securerandom'\nrequire 'hecks/model'\nrequire 'hecks/command'\nrequire 'hecks/query'\nmodule #{mod}\n  class ValidationError < StandardError; end\n  class InvariantError < StandardError; end\nend"
          end

          def aggregate_sources(mod)
            parts = []
            @domain.aggregates.each do |agg|
              safe_name = Hecks::Utils.sanitize_constant(agg.name)
              opts = { domain_module: mod }
              parts << source_for(Domain::AggregateGenerator, agg, **opts)
              AGGREGATE_GENERATORS.each do |method, gen|
                if method == :commands
                  agg.commands.each_with_index do |cmd, i|
                    src = source_for(gen, cmd, aggregate_name: safe_name, aggregate: agg, event: agg.events[i], **opts)
                    parts << inject_mixin(src, cmd.name, "Hecks::Command")
                  end
                elsif method == :queries
                  agg.send(method).each do |obj|
                    src = source_for(gen, obj, aggregate_name: safe_name, **opts)
                    parts << inject_mixin(src, obj.name, "Hecks::Query")
                  end
                else
                  agg.send(method).each { |obj| parts << source_for(gen, obj, aggregate_name: safe_name, **opts) }
                end
              end
              parts << source_for(Infrastructure::PortGenerator, agg, **opts)
              parts << source_for(Infrastructure::MemoryAdapterGenerator, agg, **opts)
            end
            parts
          end

          def source_for(klass, obj, **opts) = klass.new(obj, **opts).generate

          # For eval-based loading, inject include line since const_missing
          # (which auto-includes for file-based gems) doesn't fire.
          def inject_mixin(source, class_name, mixin)
            source.sub("class #{class_name}\n", "class #{class_name}\n        include #{mixin}\n")
          end
        end
      end
    end
  end
end

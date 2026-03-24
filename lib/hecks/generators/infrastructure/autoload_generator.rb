# Hecks::Generators::Infrastructure::AutoloadGenerator
#
# Generates autoload entry point and per-aggregate autoload declarations for
# domain gems. The entry point declares autoloads for aggregates, ports, and
# adapters. Per-aggregate autoloads cover value objects only (commands, events,
# queries, and policies are auto-discovered via const_missing at runtime).
# Part of the Generators::Infrastructure layer, consumed by DomainGemGenerator.
#
#   gen = AutoloadGenerator.new(domain)
#   gen.generate_entry_point  # => "module PizzasDomain\n  autoload :Pizza, ..."
#
module Hecks
  module Generators
    module Infrastructure
    class AutoloadGenerator
      def initialize(domain)
        @domain = domain
      end

      def generate_entry_point
        gem_name = @domain.gem_name
        mod = @domain.module_name + "Domain"

        lines = []
        lines << "require \"securerandom\""
        lines << ""
        lines << "module #{mod}"
        lines << "  class ValidationError < StandardError; end"
        lines << "  class InvariantError < StandardError; end"
        lines << ""

        @domain.aggregates.each do |agg|
          safe_name = Hecks::Utils.sanitize_constant(agg.name)
          snake = Hecks::Utils.underscore(safe_name)
          lines << "  autoload :#{safe_name}, \"#{gem_name}/#{snake}/#{snake}\""
        end

        lines << ""
        lines << "  module Ports"
        @domain.aggregates.each do |agg|
          safe_name = Hecks::Utils.sanitize_constant(agg.name)
          snake = Hecks::Utils.underscore(safe_name)
          lines << "    autoload :#{safe_name}Repository, \"#{gem_name}/ports/#{snake}_repository\""
        end
        lines << "  end"

        lines << ""
        lines << "  module Adapters"
        @domain.aggregates.each do |agg|
          safe_name = Hecks::Utils.sanitize_constant(agg.name)
          snake = Hecks::Utils.underscore(safe_name)
          lines << "    autoload :#{safe_name}MemoryRepository, \"#{gem_name}/adapters/#{snake}_memory_repository\""
        end
        lines << "  end"

        lines << "end"
        lines.join("\n") + "\n"
      end

      # Only generates value object autoloads. Commands, Events, Queries,
      # and Policies are auto-discovered by Hecks::Model via const_missing.
      def generate_aggregate_autoloads(aggregate, gem_name, domain_module)
        safe_name = Hecks::Utils.sanitize_constant(aggregate.name)
        snake = Hecks::Utils.underscore(safe_name)
        base = "#{gem_name}/#{snake}"
        base_indent = "    "

        lines = []
        aggregate.value_objects.each do |vo|
          vo_snake = Hecks::Utils.underscore(vo.name)
          lines << "#{base_indent}autoload :#{vo.name}, \"#{base}/#{vo_snake}\""
        end

        aggregate.entities.each do |ent|
          ent_snake = Hecks::Utils.underscore(ent.name)
          lines << "#{base_indent}autoload :#{ent.name}, \"#{base}/#{ent_snake}\""
        end

        lines.join("\n")
      end

    end
    end
  end
end

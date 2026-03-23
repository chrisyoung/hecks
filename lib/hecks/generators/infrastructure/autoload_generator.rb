# Hecks::Generators::Infrastructure::AutoloadGenerator
#
# Generates the entry point file with autoload declarations for the domain gem.
#
#   module PizzasDomain
#     autoload :Pizza, "pizzas_domain/pizza/pizza"
#     module Ports ...
#     module Adapters ...
#   end
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

        lines.join("\n")
      end

    end
    end
  end
end

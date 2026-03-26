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

        unless @domain.workflows.empty?
          lines << ""
          lines << "  module Workflows"
          @domain.workflows.each do |wf|
            snake = Hecks::Utils.underscore(wf.name)
            lines << "    autoload :#{wf.name}, \"#{gem_name}/workflows/#{snake}\""
          end
          lines << "  end"
        end

        unless @domain.views.empty?
          lines << ""
          lines << "  module Views"
          @domain.views.each do |v|
            snake = Hecks::Utils.underscore(v.name)
            lines << "    autoload :#{v.name}, \"#{gem_name}/views/#{snake}\""
          end
          lines << "  end"
        end

        unless @domain.services.empty?
          lines << ""
          lines << "  module Services"
          @domain.services.each do |svc|
            snake = Hecks::Utils.underscore(svc.name)
            lines << "    autoload :#{svc.name}, \"#{gem_name}/services/#{snake}\""
          end
          lines << "  end"
        end

        lines << "end"
        lines << ""
        lines << "# Auto-boot: wire a Runtime when hecks is available and gem is installed."
        lines << "# Add extension gems to your Gemfile to auto-wire:"
        lines << "#   hecks_sqlite  → SQLite persistence"
        lines << "#   hecks_postgres → PostgreSQL persistence"
        lines << "#   hecks_mysql   → MySQL persistence"
        lines << "#   hecks_serve   → HTTP/JSON-RPC server"
        lines << "#   hecks_ai      → MCP server for AI agents"
        lines << "# Remove a gem to unwire that extension. No code changes needed."
        lines << "if defined?(Hecks) && Gem.loaded_specs[\"#{gem_name}\"]"
        lines << "  _hecks_domain_file = File.join(Gem.loaded_specs[\"#{gem_name}\"].full_gem_path, \"hecks_domain.rb\")"
        lines << "  if File.exist?(_hecks_domain_file)"
        lines << "    Kernel.load(_hecks_domain_file)"
        lines << "    #{mod}.instance_variable_set(:@_hecks_domain, Hecks.last_domain)"
        lines << "  end"
        lines << ""
        lines << "  #{mod}.define_singleton_method(:boot) do |**opts, &block|"
        lines << "    domain = instance_variable_get(:@_hecks_domain)"
        lines << "    return unless domain"
        lines << "    @runtime = Hecks.load(domain, **opts, &block)"
        lines << "    Hecks.extension_registry.each { |_name, hook| hook.call(self, domain, @runtime) }"
        lines << "    @runtime"
        lines << "  end"
        lines << ""
        lines << "  #{mod}.define_singleton_method(:runtime) { @runtime }"
        lines << ""
        lines << "  #{mod}.boot unless ENV[\"HECKS_SKIP_BOOT\"]"
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

        if aggregate.lifecycle
          lines << "#{base_indent}autoload :Lifecycle, \"#{base}/lifecycle\""
        end

        lines.join("\n")
      end

    end
    end
  end
end

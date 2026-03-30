require "securerandom"

module OperationsDomain
  class ValidationError < StandardError
    attr_reader :field, :rule
    def initialize(message = nil, field: nil, rule: nil)
      @field = field; @rule = rule; super(message)
    end
  end
  class InvariantError < StandardError; end

  autoload :Deployment, "operations_domain/deployment/deployment"
  autoload :Incident, "operations_domain/incident/incident"
  autoload :Monitoring, "operations_domain/monitoring/monitoring"

  module Ports
    autoload :DeploymentRepository, "operations_domain/ports/deployment_repository"
    autoload :IncidentRepository, "operations_domain/ports/incident_repository"
    autoload :MonitoringRepository, "operations_domain/ports/monitoring_repository"
  end

  module Adapters
    autoload :DeploymentMemoryRepository, "operations_domain/adapters/deployment_memory_repository"
    autoload :IncidentMemoryRepository, "operations_domain/adapters/incident_memory_repository"
    autoload :MonitoringMemoryRepository, "operations_domain/adapters/monitoring_memory_repository"
  end
end

# Auto-boot: wire a Runtime when hecks is available and gem is installed.
# Add extension gems to your Gemfile to auto-wire:
#   hecks_sqlite  → SQLite persistence
#   hecks_postgres → PostgreSQL persistence
#   hecks_mysql   → MySQL persistence
#   hecks_serve   → HTTP/JSON-RPC server
#   hecks_ai      → MCP server for AI agents
# Remove a gem to unwire that extension. No code changes needed.
if defined?(Hecks) && Gem.loaded_specs["operations_domain"]
  _hecks_domain_file = File.join(Gem.loaded_specs["operations_domain"].full_gem_path, "hecks_domain.rb")
  if File.exist?(_hecks_domain_file)
    Kernel.load(_hecks_domain_file)
    OperationsDomain.instance_variable_set(:@_hecks_domain, Hecks.last_domain)
  end

  OperationsDomain.define_singleton_method(:boot) do |**opts, &block|
    domain = instance_variable_get(:@_hecks_domain)
    return unless domain
    @runtime = Hecks.load(domain, **opts, &block)
    Hecks.extension_registry.each { |_name, hook| hook.call(self, domain, @runtime) }
    @runtime
  end

  OperationsDomain.define_singleton_method(:runtime) { @runtime }

  OperationsDomain.boot unless ENV["HECKS_SKIP_BOOT"]
end

require "securerandom"

module ModelRegistryDomain
  class ValidationError < StandardError
    attr_reader :field, :rule
    def initialize(message = nil, field: nil, rule: nil)
      @field = field; @rule = rule; super(message)
    end
  end
  class InvariantError < StandardError; end

  autoload :AiModel, "model_registry_domain/ai_model/ai_model"
  autoload :Vendor, "model_registry_domain/vendor/vendor"
  autoload :DataUsageAgreement, "model_registry_domain/data_usage_agreement/data_usage_agreement"

  module Ports
    autoload :AiModelRepository, "model_registry_domain/ports/ai_model_repository"
    autoload :VendorRepository, "model_registry_domain/ports/vendor_repository"
    autoload :DataUsageAgreementRepository, "model_registry_domain/ports/data_usage_agreement_repository"
  end

  module Adapters
    autoload :AiModelMemoryRepository, "model_registry_domain/adapters/ai_model_memory_repository"
    autoload :VendorMemoryRepository, "model_registry_domain/adapters/vendor_memory_repository"
    autoload :DataUsageAgreementMemoryRepository, "model_registry_domain/adapters/data_usage_agreement_memory_repository"
  end

  module Workflows
    autoload :ModelApproval, "model_registry_domain/workflows/model_approval"
  end

  module Views
    autoload :ModelDashboard, "model_registry_domain/views/model_dashboard"
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
if defined?(Hecks) && Gem.loaded_specs["model_registry_domain"]
  _hecks_domain_file = File.join(Gem.loaded_specs["model_registry_domain"].full_gem_path, "Bluebook")
  if File.exist?(_hecks_domain_file)
    Kernel.load(_hecks_domain_file)
    ModelRegistryDomain.instance_variable_set(:@_hecks_domain, Hecks.last_domain)
  end

  ModelRegistryDomain.define_singleton_method(:boot) do |**opts, &block|
    domain = instance_variable_get(:@_hecks_domain)
    return unless domain
    @runtime = Hecks.load(domain, **opts, &block)
    Hecks.extension_registry.each { |_name, hook| hook.call(self, domain, @runtime) }
    @runtime
  end

  ModelRegistryDomain.define_singleton_method(:runtime) { @runtime }

  ModelRegistryDomain.boot unless ENV["HECKS_SKIP_BOOT"]
end

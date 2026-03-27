require "securerandom"

module IdentityDomain
  class ValidationError < StandardError; end
  class InvariantError < StandardError; end

  autoload :Stakeholder, "identity_domain/stakeholder/stakeholder"
  autoload :AuditLog, "identity_domain/audit_log/audit_log"

  module Ports
    autoload :StakeholderRepository, "identity_domain/ports/stakeholder_repository"
    autoload :AuditLogRepository, "identity_domain/ports/audit_log_repository"
  end

  module Adapters
    autoload :StakeholderMemoryRepository, "identity_domain/adapters/stakeholder_memory_repository"
    autoload :AuditLogMemoryRepository, "identity_domain/adapters/audit_log_memory_repository"
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
if defined?(Hecks) && Gem.loaded_specs["identity_domain"]
  _hecks_domain_file = File.join(Gem.loaded_specs["identity_domain"].full_gem_path, "hecks_domain.rb")
  if File.exist?(_hecks_domain_file)
    Kernel.load(_hecks_domain_file)
    IdentityDomain.instance_variable_set(:@_hecks_domain, Hecks.last_domain)
  end

  IdentityDomain.define_singleton_method(:boot) do |**opts, &block|
    domain = instance_variable_get(:@_hecks_domain)
    return unless domain
    @runtime = Hecks.load(domain, **opts, &block)
    Hecks.extension_registry.each { |_name, hook| hook.call(self, domain, @runtime) }
    @runtime
  end

  IdentityDomain.define_singleton_method(:runtime) { @runtime }

  IdentityDomain.boot unless ENV["HECKS_SKIP_BOOT"]
end

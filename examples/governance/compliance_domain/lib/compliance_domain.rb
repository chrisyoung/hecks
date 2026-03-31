require "securerandom"

module ComplianceDomain
  class ValidationError < StandardError
    attr_reader :field, :rule
    def initialize(message = nil, field: nil, rule: nil)
      @field = field; @rule = rule; super(message)
    end
  end
  class InvariantError < StandardError; end

  autoload :GovernancePolicy, "compliance_domain/governance_policy/governance_policy"
  autoload :RegulatoryFramework, "compliance_domain/regulatory_framework/regulatory_framework"
  autoload :ComplianceReview, "compliance_domain/compliance_review/compliance_review"
  autoload :Exemption, "compliance_domain/exemption/exemption"
  autoload :TrainingRecord, "compliance_domain/training_record/training_record"

  module Ports
    autoload :GovernancePolicyRepository, "compliance_domain/ports/governance_policy_repository"
    autoload :RegulatoryFrameworkRepository, "compliance_domain/ports/regulatory_framework_repository"
    autoload :ComplianceReviewRepository, "compliance_domain/ports/compliance_review_repository"
    autoload :ExemptionRepository, "compliance_domain/ports/exemption_repository"
    autoload :TrainingRecordRepository, "compliance_domain/ports/training_record_repository"
  end

  module Adapters
    autoload :GovernancePolicyMemoryRepository, "compliance_domain/adapters/governance_policy_memory_repository"
    autoload :RegulatoryFrameworkMemoryRepository, "compliance_domain/adapters/regulatory_framework_memory_repository"
    autoload :ComplianceReviewMemoryRepository, "compliance_domain/adapters/compliance_review_memory_repository"
    autoload :ExemptionMemoryRepository, "compliance_domain/adapters/exemption_memory_repository"
    autoload :TrainingRecordMemoryRepository, "compliance_domain/adapters/training_record_memory_repository"
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
if defined?(Hecks) && Gem.loaded_specs["compliance_domain"]
  _hecks_domain_file = File.join(Gem.loaded_specs["compliance_domain"].full_gem_path, "Bluebook")
  if File.exist?(_hecks_domain_file)
    Kernel.load(_hecks_domain_file)
    ComplianceDomain.instance_variable_set(:@_hecks_domain, Hecks.last_domain)
  end

  ComplianceDomain.define_singleton_method(:boot) do |**opts, &block|
    domain = instance_variable_get(:@_hecks_domain)
    return unless domain
    @runtime = Hecks.load(domain, **opts, &block)
    Hecks.extension_registry.each { |_name, hook| hook.call(self, domain, @runtime) }
    @runtime
  end

  ComplianceDomain.define_singleton_method(:runtime) { @runtime }

  ComplianceDomain.boot unless ENV["HECKS_SKIP_BOOT"]
end

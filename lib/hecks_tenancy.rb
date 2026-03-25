# HecksTenancy
#
# Multi-tenancy connection for Hecks domains. Wraps repositories with
# tenant-scoped proxies so each tenant sees isolated data. Declare
# the strategy in the DSL with `tenancy :column`.
#
# Future gem: hecks_tenancy
#
#   # Gemfile
#   gem "cats_domain"
#   gem "hecks_tenancy"
#
#   # Console
#   Hecks.tenant = "acme"
#   Cat.create(name: "Whiskers")   # stored under acme
#
require_relative "hecks_tenancy/tenant_scoped_repository"

Hecks.register_connection(:tenancy) do |domain_mod, domain, runtime|
  next unless domain.tenancy

  domain.aggregates.each do |agg|
    repo = runtime[agg.name]
    proxy = HecksTenancy::TenantScopedRepository.new(repo.class)
    runtime.swap_adapter(agg.name, proxy)
  end
end

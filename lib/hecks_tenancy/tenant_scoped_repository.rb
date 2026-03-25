# HecksTenancy::TenantScopedRepository
#
# Repository proxy that isolates data per tenant. Wraps a repository class
# and maintains separate instances keyed by tenant ID. All operations
# delegate to the current tenant's store via Hecks.tenant.
#
#   proxy = TenantScopedRepository.new(PizzaMemoryRepository)
#   Hecks.tenant = "acme"
#   proxy.save(pizza)     # stored under acme
#   Hecks.tenant = "beta"
#   proxy.all             # => [] (beta has nothing)
#
module HecksTenancy
  class TenantScopedRepository
    def initialize(repo_class)
      @repo_class = repo_class
      @stores = {}
    end

    def for_tenant
      tenant = Hecks.tenant || "__default__"
      @stores[tenant] ||= @repo_class.new
    end

    def find(id)
      for_tenant.find(id)
    end

    def save(aggregate)
      for_tenant.save(aggregate)
    end

    def delete(id)
      for_tenant.delete(id)
    end

    def all
      for_tenant.all
    end

    def count
      for_tenant.count
    end

    def clear
      for_tenant.clear
    end

    def query(**kwargs)
      for_tenant.query(**kwargs)
    end
  end
end

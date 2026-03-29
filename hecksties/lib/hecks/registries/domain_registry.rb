# Hecks::DomainRegistryMethods
#
# Domain caching, load strategy, and last_domain tracking.
# Extracted from the Hecks module.
#
module Hecks
  module DomainRegistryMethods
    def last_domain
      @last_domain
    end

    def last_domain=(domain)
      @last_domain = domain
    end

    def load_strategy
      @load_strategy
    end

    def load_strategy=(strategy)
      @load_strategy = strategy
    end

    def loaded_domains
      @loaded_domains
    end

    def domain_objects
      @domain_objects
    end
  end
end

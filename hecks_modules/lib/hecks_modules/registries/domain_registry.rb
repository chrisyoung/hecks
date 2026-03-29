# Hecks::DomainRegistryMethods
#
# Domain caching, load strategy, and last_domain tracking.
# Extracted from the Hecks module.
#
module Hecks
  module DomainRegistryMethods
    extend ModuleDSL

    lazy_registry :loaded_domains
    lazy_registry :domain_objects

    def last_domain
      @last_domain
    end

    def last_domain=(domain)
      @last_domain = domain
    end

    def load_strategy
      @load_strategy ||= :memory
    end

    def load_strategy=(strategy)
      @load_strategy = strategy
    end
  end
end

# Hecks::AdapterRegistryMethods
#
# Registry for persistence adapter types. Each adapter (memory, sqlite, etc.)
# registers itself so that DomainConnections and Boot can check adapter
# availability without hardcoded lists.
#
#   Hecks.register_adapter(:sqlite)
#   Hecks.registered_adapters  # => [:memory, :sqlite, ...]
#   Hecks.adapter?(:sqlite)    # => true
#
module Hecks
  module AdapterRegistryMethods
    extend ModuleDSL

    lazy_registry(:adapter_registry, private: true) { %i[memory sqlite postgres mysql mysql2 filesystem filesystem_store] }

    def registered_adapters
      adapter_registry.dup
    end

    def register_adapter(name)
      adapter_registry << name.to_sym unless adapter_registry.include?(name.to_sym)
    end

    def adapter?(name)
      adapter_registry.include?(name.to_sym)
    end
  end
end

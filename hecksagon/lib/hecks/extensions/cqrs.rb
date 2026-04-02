require "hecks"

# HecksCqrs
#
# CQRS (Command Query Responsibility Segregation) support for Hecks domains.
# Enables separate read and write repositories. Commands route to the write
# repository, queries and scopes route to the read repository. When only a
# single adapter is configured, behavior is unchanged (backward compatible).
#
# Activate CQRS by declaring named :write and :read persist connections:
#
#   CatsDomain.boot do
#     persist_to :write, :sqlite
#     persist_to :read, :sqlite, database: "read.db"
#   end
#
# Or programmatically after boot:
#
#   runtime.enable_cqrs("Pizza", read_repo: my_read_repo)
#
# The read store wraps the read adapter in a ReadModelStore, which auto-syncs
# from command events on the event bus.
#

module HecksCqrs
  VERSION = "2026.04.01.1"

  # Check whether a domain module has CQRS connections configured.
  # Returns true when more than one named persist connection exists,
  # indicating separate read and write paths.
  #
  # @param mod [Module] a domain module that includes DomainConnections;
  #   must respond to +connections+ returning a Hash with a +:persist+ key
  # @return [Boolean] true if the module has multiple persist connections
  def self.active?(mod)
    return false unless mod.respond_to?(:connections)

    persist = mod.connections[:persist]
    persist.is_a?(Hash) && persist.size > 1
  end

  # Return the adapter configuration hash for a named connection, or nil
  # if the connection does not exist or the module has no connections.
  #
  # @param mod [Module] a domain module that includes DomainConnections
  # @param name [Symbol] connection name, typically +:write+ or +:read+,
  #   but can also be +:default+ or any custom name
  # @return [Hash, nil] the adapter configuration hash (e.g.
  #   +{ type: :sqlite, database: "read.db" }+), or nil if not found
  def self.connection_for(mod, name)
    return nil unless mod.respond_to?(:connections)

    persist = mod.connections[:persist]
    persist[name] if persist.is_a?(Hash)
  end

  # Wires CQRS read/write separation onto a runtime.
  #
  # For each aggregate, creates a ReadModelStore backed by a fresh memory
  # adapter, subscribes to all aggregate events to auto-sync the read store,
  # and registers the read repository on the runtime for query routing.
  #
  # @param mod [Module] the domain module
  # @param domain [Object] the domain IR
  # @param runtime [Hecks::Runtime] the runtime to wire CQRS onto
  # @return [void]
  def self.call(mod, domain, runtime, **_kwargs)
    require "hecks/ports/read_model_store"

    domain.aggregates.each do |agg|
      write_repo = runtime[agg.name]
      adapter_class = mod::Adapters.const_get("#{agg.name}MemoryRepository")
      read_adapter = adapter_class.new
      read_store = Hecks::ReadModelStore.new(adapter: read_adapter)

      # Auto-sync: on every aggregate event, copy the aggregate to the read store
      agg.events.each do |event|
        runtime.event_bus.subscribe(event.name) do |evt|
          # Re-read from write repo and sync to read store
          agg_class = mod.const_get(agg.name)
          write_repo.all.each { |obj| read_store.update(obj) }
        end
      end

      runtime.register_read_store(agg.name, read_store)
    end
  end
end

# Register with Hecks extension registry if available
if defined?(Hecks) && Hecks.respond_to?(:extension_registry)
  Hecks.extension_registry[:cqrs] = HecksCqrs
end

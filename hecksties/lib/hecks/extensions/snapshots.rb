# HecksSnapshots
#
# Aggregate snapshot extension for event-sourced domains. Provides a snapshot
# store port (save_snapshot, load_snapshot), memory-backed implementation,
# aggregate reconstitution from snapshot + events, and automatic snapshotting
# after a configurable number of events (default 100).
#
# Usage:
#   require "hecks/extensions/snapshots"
#
#   app = Hecks.load(domain)
#   app.extend(:snapshots)
#
#   # Or with custom threshold:
#   app.extend(:snapshots, threshold: 50)
#
#   # Reconstitute from snapshot + events:
#   Hecks.snapshot_store.load_snapshot("Pizza", pizza_id)
#
require_relative "snapshots/memory_snapshot_store"
require_relative "snapshots/reconstitution"
require_relative "snapshots/auto_snapshot"

module Hecks
  module Snapshots
    # Registers DSL `apply` blocks on an aggregate class.
    #
    # @param klass [Class] the aggregate class
    # @param event_name [String] the event type name (e.g., "CreatedPizza")
    # @param block [Proc] a block receiving (aggregate, event_data) and returning new aggregate
    # @return [void]
    def self.register_applier(klass, event_name, &block)
      appliers = klass.instance_variable_get(:@__hecks_appliers__) || {}
      appliers[event_name] = block
      klass.instance_variable_set(:@__hecks_appliers__, appliers)
    end
  end
end

# Extension registration: describe and register with Hecks runtime.
Hecks.describe_extension(:snapshots,
  description: "Aggregate snapshots for event-sourced reconstitution",
  adapter_type: :driven,
  config: { threshold: { default: 100, type: Integer } },
  wires_to: :event_bus)

Hecks.register_extension(:snapshots) do |domain_mod, domain, runtime, **opts|
  threshold = opts.fetch(:threshold, 100)
  store = Hecks::Snapshots::MemorySnapshotStore.new

  Hecks.instance_variable_set(:@_snapshot_store, store)
  Hecks.define_singleton_method(:snapshot_store) { @_snapshot_store }

  resolver = ->(agg_type, agg_id) {
    domain.aggregates.each do |agg|
      next unless agg.name == agg_type
      klass_name = "#{domain_mod}::#{agg.name}"
      klass = Object.const_get(klass_name) rescue nil
      return klass.find(agg_id) if klass&.respond_to?(:find)
    end
    nil
  }

  Hecks::Snapshots::AutoSnapshot.new(
    snapshot_store: store,
    event_bus: runtime.event_bus,
    threshold: threshold,
    aggregate_resolver: resolver
  )
end

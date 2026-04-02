# Hecks::Snapshots::MemorySnapshotStore
#
# In-memory snapshot store for aggregate state. Stores snapshots keyed by
# aggregate type and ID, with a version number corresponding to the event
# stream position at the time of the snapshot.
#
# Each snapshot is a Hash with :aggregate_type, :aggregate_id, :version,
# :state (the serialized attribute hash), and :taken_at timestamp.
#
# Usage:
#   store = Hecks::Snapshots::MemorySnapshotStore.new
#   store.save_snapshot("Pizza", "abc-123", version: 50, state: { name: "Margherita" })
#   snap = store.load_snapshot("Pizza", "abc-123")
#   snap[:version]  # => 50
#   snap[:state]    # => { name: "Margherita" }
#
module Hecks
  module Snapshots
    class MemorySnapshotStore
      def initialize
        @store = {}
      end

      # Saves a snapshot of an aggregate's state at a given event version.
      #
      # @param aggregate_type [String] the aggregate type name (e.g., "Pizza")
      # @param aggregate_id [String, Integer] the aggregate instance ID
      # @param version [Integer] the event stream version this snapshot represents
      # @param state [Hash] the serialized aggregate attributes
      # @return [Hash] the stored snapshot
      def save_snapshot(aggregate_type, aggregate_id, version:, state:)
        key = snapshot_key(aggregate_type, aggregate_id)
        snapshot = {
          aggregate_type: aggregate_type,
          aggregate_id: aggregate_id,
          version: version,
          state: state,
          taken_at: Time.now
        }
        @store[key] = snapshot
      end

      # Loads the most recent snapshot for an aggregate instance.
      #
      # @param aggregate_type [String] the aggregate type name
      # @param aggregate_id [String, Integer] the aggregate instance ID
      # @return [Hash, nil] the snapshot hash, or nil if none exists
      def load_snapshot(aggregate_type, aggregate_id)
        @store[snapshot_key(aggregate_type, aggregate_id)]
      end

      # Removes all stored snapshots.
      #
      # @return [void]
      def clear
        @store.clear
      end

      private

      # Builds the storage key for a given aggregate.
      #
      # @param aggregate_type [String] the aggregate type name
      # @param aggregate_id [String, Integer] the aggregate instance ID
      # @return [String] the composite key
      def snapshot_key(aggregate_type, aggregate_id)
        "#{aggregate_type}-#{aggregate_id}"
      end
    end
  end
end

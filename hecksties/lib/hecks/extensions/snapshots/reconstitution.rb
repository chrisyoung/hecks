# Hecks::Snapshots::Reconstitution
#
# Rebuilds an aggregate from a snapshot plus subsequent events. Uses the
# aggregate class's registered `apply` blocks to fold each event onto
# the reconstituted state.
#
# The reconstitution flow:
#   1. Load the latest snapshot (or start from a blank state)
#   2. Fetch events after the snapshot version
#   3. Fold each event through the aggregate's `apply` block
#   4. Return the rebuilt aggregate instance
#
# Usage:
#   aggregate = Hecks::Snapshots::Reconstitution.reconstitute(
#     Pizza, "abc-123",
#     snapshot_store: store,
#     event_history: events_after_version
#   )
#
module Hecks
  module Snapshots
    module Reconstitution
      # Rebuilds an aggregate from snapshot + events.
      #
      # @param klass [Class] the aggregate class (e.g., Pizza)
      # @param aggregate_id [String, Integer] the aggregate instance ID
      # @param snapshot_store [MemorySnapshotStore] the snapshot store
      # @param event_recorder [Object] object responding to #history(type, id)
      # @return [Object, nil] the reconstituted aggregate, or nil if no history
      def self.reconstitute(klass, aggregate_id, snapshot_store:, event_recorder:)
        agg_type = klass.name.split("::").last
        snapshot = snapshot_store.load_snapshot(agg_type, aggregate_id)
        appliers = klass.instance_variable_get(:@__hecks_appliers__) || {}

        if snapshot
          aggregate = klass.new(**symbolize_keys(snapshot[:state]))
          events = events_after(event_recorder, agg_type, aggregate_id, snapshot[:version])
        else
          all_events = event_recorder.history(agg_type, aggregate_id)
          return nil if all_events.empty?
          aggregate = nil
          events = all_events
        end

        events.each do |event_hash|
          event_name = event_hash[:event_type]
          applier = appliers[event_name]
          next unless applier
          aggregate = applier.call(aggregate, event_hash[:data])
        end

        aggregate
      end

      # Fetches events after a given version from the event recorder.
      #
      # @param recorder [Object] event recorder with #history method
      # @param agg_type [String] aggregate type name
      # @param agg_id [String, Integer] aggregate ID
      # @param after_version [Integer] only return events with version > this
      # @return [Array<Hash>] filtered event hashes
      def self.events_after(recorder, agg_type, agg_id, after_version)
        recorder.history(agg_type, agg_id).select { |e| e[:version] > after_version }
      end

      # Converts string keys to symbols for aggregate construction.
      #
      # @param hash [Hash] the hash to convert
      # @return [Hash] hash with symbol keys
      def self.symbolize_keys(hash)
        hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      end

      private_class_method :events_after, :symbolize_keys
    end
  end
end

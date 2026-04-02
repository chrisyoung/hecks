# Hecks::Snapshots::AutoSnapshot
#
# Event bus listener that automatically takes a snapshot of an aggregate
# after every N events. Configurable threshold (default 100). Subscribes
# to the event bus via `on_any` and tracks event counts per aggregate
# stream. When the threshold is reached, serializes the current aggregate
# state and saves it to the snapshot store.
#
# Usage:
#   auto = Hecks::Snapshots::AutoSnapshot.new(
#     snapshot_store: store,
#     event_bus: bus,
#     threshold: 50,
#     aggregate_resolver: ->(type, id) { klass.find(id) }
#   )
#
module Hecks
  module Snapshots
    class AutoSnapshot
      # @return [Integer] the event count threshold that triggers a snapshot
      attr_reader :threshold

      # Creates an auto-snapshot listener and subscribes to the event bus.
      #
      # @param snapshot_store [MemorySnapshotStore] where to save snapshots
      # @param event_bus [Hecks::EventBus] the event bus to listen on
      # @param threshold [Integer] number of events between snapshots (default 100)
      # @param aggregate_resolver [Proc] callable(type, id) that returns the aggregate
      def initialize(snapshot_store:, event_bus:, threshold: 100, aggregate_resolver:)
        @snapshot_store = snapshot_store
        @threshold = threshold
        @aggregate_resolver = aggregate_resolver
        @event_counts = Hash.new(0)
        event_bus.on_any { |event| check_and_snapshot(event) }
      end

      private

      # Checks if the event count for this stream has reached the threshold,
      # and if so, takes a snapshot.
      #
      # @param event [Object] the domain event
      # @return [void]
      def check_and_snapshot(event)
        agg_type, agg_id = extract_stream_info(event)
        return unless agg_type && agg_id

        key = "#{agg_type}-#{agg_id}"
        @event_counts[key] += 1

        return unless @event_counts[key] >= @threshold

        take_snapshot(agg_type, agg_id, @event_counts[key])
        @event_counts[key] = 0
      end

      # Extracts the aggregate type and ID from a domain event.
      #
      # @param event [Object] the domain event
      # @return [Array(String, String)] [aggregate_type, aggregate_id]
      def extract_stream_info(event)
        agg_id = event.respond_to?(:aggregate_id) ? event.aggregate_id : event.respond_to?(:id) ? event.id : nil
        return [nil, nil] unless agg_id

        event_name = Hecks::Utils.const_short_name(event)
        agg_type = infer_aggregate_type(event_name)
        [agg_type, agg_id]
      end

      # Infers the aggregate type from an event class name by looking at the
      # module hierarchy (e.g., PizzasDomain::Pizza::Events::CreatedPizza -> Pizza).
      #
      # @param event_name [String] the short event class name
      # @return [String] the aggregate type name
      def infer_aggregate_type(event_name)
        event_name
          .gsub(/^(Created|Updated|Deleted|Placed|Approved|Rejected|Completed)/, "")
      end

      # Saves a snapshot of the aggregate's current state.
      #
      # @param agg_type [String] the aggregate type
      # @param agg_id [String, Integer] the aggregate ID
      # @param version [Integer] the event count (used as version)
      # @return [void]
      def take_snapshot(agg_type, agg_id, version)
        aggregate = @aggregate_resolver.call(agg_type, agg_id)
        return unless aggregate

        state = serialize_aggregate(aggregate)
        @snapshot_store.save_snapshot(agg_type, agg_id, version: version, state: state)
      end

      # Serializes an aggregate to a hash of its attributes.
      #
      # @param aggregate [Object] the aggregate instance
      # @return [Hash] the serialized state
      def serialize_aggregate(aggregate)
        if aggregate.class.respond_to?(:hecks_attributes)
          attrs = { id: aggregate.id }
          aggregate.class.hecks_attributes.each do |attr|
            attrs[attr.name.to_sym] = aggregate.send(attr.name)
          end
          attrs
        else
          params = aggregate.class.instance_method(:initialize).parameters
          attrs = { id: aggregate.id }
          params.each do |_, name|
            next unless name && name != :id
            attrs[name] = aggregate.send(name) if aggregate.respond_to?(name)
          end
          attrs
        end
      end
    end
  end
end

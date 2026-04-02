# Hecks::WebExplorer::EventIntrospector
#
# Reads events from the EventBus and provides filtered, structured
# access for the Web Explorer event log browser. Extracts event type,
# aggregate type, timestamp, and payload from published domain events.
#
#   introspector = EventIntrospector.new(event_bus)
#   introspector.all_entries                              # => [{ type: ..., ... }]
#   introspector.all_entries(type_filter: "CreatedPizza") # filtered by type
#   introspector.event_types                              # => ["CreatedPizza", "PlacedOrder"]
#   introspector.aggregate_types                          # => ["Pizza", "Order"]
#
module Hecks
  module WebExplorer
    class EventIntrospector
      def initialize(event_bus)
        @event_bus = event_bus
      end

      # Returns all events as structured hashes, optionally filtered.
      #
      # @param type_filter [String, nil] filter by event type short name
      # @param aggregate_filter [String, nil] filter by aggregate type
      # @return [Array<Hash>] entries with :type, :aggregate, :occurred_at, :payload
      def all_entries(type_filter: nil, aggregate_filter: nil)
        entries = @event_bus.events.map { |e| entry_for(e) }
        entries = entries.select { |e| e[:type] == type_filter } if type_filter && !type_filter.empty?
        entries = entries.select { |e| e[:aggregate] == aggregate_filter } if aggregate_filter && !aggregate_filter.empty?
        entries.reverse
      end

      # Returns all unique event type names from the log.
      #
      # @return [Array<String>] sorted unique event type names
      def event_types
        @event_bus.events.map { |e| short_name(e) }.uniq.sort
      end

      # Returns all unique aggregate type names from the log.
      #
      # @return [Array<String>] sorted unique aggregate type names
      def aggregate_types
        @event_bus.events.map { |e| extract_aggregate(e) }.compact.uniq.sort
      end

      private

      def entry_for(event)
        {
          type: short_name(event),
          aggregate: extract_aggregate(event),
          occurred_at: format_time(event),
          payload: extract_payload(event)
        }
      end

      def short_name(event)
        Hecks::Utils.const_short_name(event)
      end

      def extract_aggregate(event)
        parts = event.class.name.to_s.split("::")
        events_idx = parts.index("Events")
        events_idx && events_idx > 0 ? parts[events_idx - 1] : nil
      end

      def format_time(event)
        return nil unless event.respond_to?(:occurred_at) && event.occurred_at
        event.occurred_at.strftime("%Y-%m-%d %H:%M:%S")
      end

      def extract_payload(event)
        params = event.class.instance_method(:initialize).parameters
        params.each_with_object({}) do |(_, name), h|
          next unless name && name != :occurred_at
          h[name.to_s] = event.respond_to?(name) ? event.send(name).to_s : nil
        end
      end
    end
  end
end

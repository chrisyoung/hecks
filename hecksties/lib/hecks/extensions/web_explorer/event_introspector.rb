# Hecks::WebExplorer::EventIntrospector
#
# Reads the event log from an EventBus and provides structured data for
# the web explorer events view. Formats each event with its type, timestamp,
# and payload for display in the events.erb template.
#
#   introspector = EventIntrospector.new(event_bus)
#   introspector.recent_events(limit: 50)
#   # => [{ type: "CreatedPizza", occurred_at: "2026-04-01T...", payload: {...} }, ...]
#
module Hecks
  module WebExplorer
    class EventIntrospector
      def initialize(event_bus)
        @event_bus = event_bus
      end

      def recent_events(limit: 50)
        events = @event_bus.events.last(limit).reverse
        events.map { |e| format_event(e) }
      end

      def event_count
        @event_bus.events.size
      end

      private

      def format_event(event)
        {
          type: Hecks::Utils.const_short_name(event),
          occurred_at: format_time(event),
          payload: extract_payload(event)
        }
      end

      def format_time(event)
        if event.respond_to?(:occurred_at)
          event.occurred_at.iso8601
        else
          Time.now.iso8601
        end
      end

      def extract_payload(event)
        if event.respond_to?(:to_h)
          event.to_h
        elsif event.respond_to?(:aggregate)
          { aggregate_id: event.aggregate.id.to_s }
        else
          {}
        end
      end
    end
  end
end

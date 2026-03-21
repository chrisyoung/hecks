# Hecks::Services::EventBus
#
# Simple in-process publish/subscribe event bus. Stores all published events
# and notifies registered listeners by event class name.
#
# Part of the Services layer. Used by Application and CommandRunner to
# decouple command execution from event handling and policy triggering.
#
#   bus = EventBus.new
#   bus.subscribe("CreatedPizza") { |event| puts event.name }
#   bus.publish(pizza_created_event)
#   bus.events  # => [#<CreatedPizza ...>]
#   bus.clear   # empties the event log
#
module Hecks
  module Services
    class EventBus
      attr_reader :events

      def initialize
        @listeners = Hash.new { |h, k| h[k] = [] }
        @events = []
      end

      def subscribe(event_name, &handler)
        @listeners[event_name.to_s] << handler
      end

      def publish(event)
        @events << event
        event_name = event.class.name.split("::").last
        @listeners[event_name].each { |handler| handler.call(event) }
      end

      def clear
        @events.clear
      end
    end
  end
end

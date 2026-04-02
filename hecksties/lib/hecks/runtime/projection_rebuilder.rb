# Hecks::ProjectionRebuilder
#
# Replays historical events through projection functions to rebuild
# read model state. Used by ViewBinding when a view declares
# `from_stream` to catch up on events that occurred before the
# subscription was established.
#
#   events = event_bus.events
#   projections = { "PlacedOrder" => proc { |e, s| s.merge(count: (s[:count] || 0) + 1) } }
#   state = ProjectionRebuilder.replay(events, projections)
#   # => { count: 3 }
#
module Hecks
  class ProjectionRebuilder
    # Replays a list of events through projection functions, accumulating state.
    #
    # For each event, looks up a matching projection by the event's short class
    # name. If a projection exists, calls it with the event and current state,
    # replacing state with the return value. Events with no matching projection
    # are skipped.
    #
    # @param events [Array<Object>] ordered list of domain events to replay
    # @param projections [Hash{String => Proc}] event name to projection proc mapping
    # @param initial_state [Hash] starting state (defaults to empty hash)
    # @return [Hash] the accumulated projection state after all events
    def self.replay(events, projections, initial_state: {})
      events.each_with_object(initial_state.dup) do |event, state|
        event_name = Hecks::Utils.const_short_name(event)
        projection = projections[event_name]
        next unless projection

        result = projection.call(event, state)
        state.replace(result) if result.is_a?(Hash)
      end
    end
  end
end

# HecksTracing
#
# Distributed tracing extension that adds a +trace_id+ to the thread
# context and stamps it on every published event. Enables correlation
# of commands and events across service boundaries. Since domain events
# are frozen, trace_ids are stored in a side table keyed by event
# +object_id+, accessible via +Hecks.event_trace_id(event)+.
#
# Usage:
#   Hecks.trace_id = SecureRandom.uuid
#   Pizza.create(name: "Margherita")
#   Hecks.event_trace_id(app.events.last)  # => "<the uuid>"
#
Hecks.describe_extension(:tracing,
  description: "Distributed tracing via trace_id on events",
  adapter_type: :driven,
  config: {},
  wires_to: :event_bus)

Hecks.register_extension(:tracing) do |_domain_mod, _domain, runtime|
  trace_map = {}
  Hecks.instance_variable_set(:@_trace_map, trace_map)

  Hecks.define_singleton_method(:event_trace_id) do |event|
    @_trace_map[event.object_id]
  end

  Hecks.define_singleton_method(:traced_events) do
    @_trace_map.dup
  end

  runtime.event_bus.on_any do |event|
    tid = Hecks.trace_id
    trace_map[event.object_id] = tid if tid
  end
end

# HecksTracing
#
# Distributed tracing extension for the Hecks event bus. Ensures every
# domain event carries a trace ID for correlation. When a trace ID is
# already set on the thread (e.g. propagated from an incoming HTTP header
# via +Hecks.trace_id=+), events are stamped with that value. When no
# trace ID is present, one is auto-generated per event.
#
# Usage:
#   Hecks.boot(__dir__, extend: :tracing)
#   Pizza.create(name: "Margherita")
#   Hecks.event_bus.events.last.instance_variable_get(:@_trace_id)
#   # => "a1b2c3d4-..."
#
#   # Propagate an incoming trace:
#   Hecks.with_trace(request.headers["X-Trace-Id"]) do
#     Pizza.create(name: "Pepperoni")
#   end
#
require "securerandom"

Hecks.describe_extension(:tracing,
  description: "Distributed tracing — correlation IDs on every event",
  adapter_type: :driven,
  config: {},
  wires_to: :event_bus)

Hecks.register_extension(:tracing) do |_domain_mod, _domain, runtime|
  bus = Hecks.event_bus || runtime.event_bus
  bus.instance_variable_set(:@auto_trace, true)
end

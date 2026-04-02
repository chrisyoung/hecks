# Distributed Tracing

The `:tracing` extension stamps a correlation ID (`@_trace_id`) on every
domain event published through the event bus. This lets you correlate events
across aggregates, services, and log systems.

## Setup

```ruby
# In your Bluebook connections block:
extend :tracing
```

Or boot manually:

```ruby
require "hecks/extensions/tracing"

app = Hecks.boot(__dir__)
Hecks.extension_registry[:tracing].call(PizzasDomain, domain, app)
```

## Auto-generated trace IDs

When no trace ID is set on the thread, each event gets a fresh UUID:

```ruby
Pizza.create(name: "Margherita")
event = app.event_bus.events.last
event.instance_variable_get(:@_trace_id)
# => "f47ac10b-58cc-4372-a567-0e02b2c3d479"
```

## Propagating upstream trace IDs

Set the trace ID before dispatching commands. This is typically done in
Rack middleware or a controller before-action:

```ruby
# From an HTTP header:
Hecks.trace_id = request.headers["X-Trace-Id"]
Pizza.create(name: "Pepperoni")

event = app.event_bus.events.last
event.instance_variable_get(:@_trace_id)
# => the same value from the header
```

## Scoped tracing with `with_trace`

Use `with_trace` to scope a trace ID to a block. It auto-generates a UUID
when called without an argument:

```ruby
Hecks.with_trace do |trace_id|
  puts trace_id  # => "a1b2c3d4-..."
  Pizza.create(name: "Hawaiian")
end
# trace_id is nil again here
```

Pass an explicit ID to propagate from upstream:

```ruby
Hecks.with_trace("upstream-trace-xyz") do |id|
  Pizza.create(name: "BBQ Chicken")
end
```

## Reading trace IDs from events

Events carry the trace ID as an instance variable (not a formal attribute)
so the event's constructor contract is unchanged:

```ruby
app.event_bus.events.each do |event|
  trace = event.instance_variable_get(:@_trace_id)
  puts "#{event.class.name.split('::').last} trace=#{trace}"
end
```

## Thread safety

Trace IDs are stored in `Thread.current[:hecks_trace_id]`, so each thread
(or Fiber with thread-local storage) gets its own trace context. This is
safe for multi-threaded servers like Puma.

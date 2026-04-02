# Distributed Tracing

Correlate commands and events across service boundaries with a thread-local
`trace_id` that is automatically stamped on every published event.

## Setup

```ruby
app = Hecks.boot(__dir__)
app.extend(:tracing)
```

Or in configuration:

```ruby
Hecks.configure do
  extensions :tracing
end
```

## Usage

```ruby
# Set trace_id from an incoming request header
Hecks.trace_id = request.headers["X-Trace-Id"]

Pizza.create(name: "Margherita")

# Retrieve the trace_id for any event
event = app.events.last
Hecks.event_trace_id(event)  # => "abc-123"
```

## Scoped Tracing

```ruby
Hecks.with_trace("request-uuid") do
  Pizza.create(name: "Margherita")
  # All events in this block are tagged with "request-uuid"
end

Hecks.trace_id  # => nil (restored)
```

## API

| Method | Description |
|--------|-------------|
| `Hecks.trace_id` | Read current thread trace_id |
| `Hecks.trace_id=` | Set current thread trace_id |
| `Hecks.with_trace(id) { }` | Scoped trace_id block |
| `Hecks.event_trace_id(event)` | Get trace_id for a published event |
| `Hecks.traced_events` | Hash of all event_object_id => trace_id mappings |

# Event Log Browser (HEC-262)

Browse domain events in the Web Explorer UI.

## Route

```
GET /events
```

Displays a table of recent domain events with type, timestamp, and payload.

## EventIntrospector API

```ruby
introspector = Hecks::WebExplorer::EventIntrospector.new(runtime.event_bus)
introspector.event_count        # => 42
introspector.recent_events      # => [{ type: "CreatedPizza", occurred_at: "...", payload: {...} }, ...]
introspector.recent_events(limit: 10)  # last 10 events, newest first
```

## Navigation

"Events" appears in the sidebar under the "System" group, alongside "Config".

## Multi-Domain

In multi-domain mode, events from all domains are merged and sorted by timestamp.

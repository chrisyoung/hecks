# Event Log Browser

Browse all published domain events in a filterable HTML table within
the Web Explorer UI.

## Access

Navigate to `/events` in your browser when the domain server is running,
or click the "Events" link in the sidebar under the System group.

## Filtering

The filter bar provides two dropdowns:

- **Event Type** -- filter by event class name (e.g., `CreatedPizza`, `PlacedOrder`)
- **Aggregate** -- filter by aggregate type (e.g., `Pizza`, `Order`)

Select a value and click "Filter" to narrow the results. Select "All" to
clear a filter.

## Table Columns

| Column    | Description                                              |
|-----------|----------------------------------------------------------|
| Timestamp | When the event occurred (`YYYY-MM-DD HH:MM:SS`)         |
| Type      | Event class short name, shown as a badge                 |
| Aggregate | The aggregate that emitted the event                     |
| Payload   | Expandable `<details>` with event attribute key/values   |

Events are displayed in reverse chronological order (newest first).

## Programmatic Access

```ruby
require "hecks/extensions/web_explorer/event_introspector"

bus = app.event_bus
introspector = Hecks::WebExplorer::EventIntrospector.new(bus)

# All events
introspector.all_entries
# => [{ type: "PlacedOrder", aggregate: "Order", occurred_at: "2026-04-01 12:00:00", payload: { ... } }, ...]

# Filtered
introspector.all_entries(type_filter: "CreatedPizza")
introspector.all_entries(aggregate_filter: "Order")

# Available filter values
introspector.event_types      # => ["CreatedPizza", "PlacedOrder"]
introspector.aggregate_types  # => ["Order", "Pizza"]
```

## Multi-Domain

In multi-domain mode, the event browser aggregates events from all
domain event buses into a single combined view. Filters work across
all domains.

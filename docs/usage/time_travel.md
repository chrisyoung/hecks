# Time Travel — Replay Events to Point in Time

Hecks automatically records every domain event published through the event bus
into an in-memory `EventStore`. This enables replaying events to reconstruct
aggregate state at any past point in time or at a specific version number.

## Setup

Time travel is built in — no extra configuration needed. Every `Hecks.load` or
`Hecks.boot` call wires the event store automatically.

```ruby
domain = Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    attribute :style, String

    command "CreatePizza" do
      attribute :name, String
      attribute :style, String
    end

    command "RenamePizza" do
      reference_to "Pizza"
      attribute :name, String
    end
  end
end

app = Hecks.load(domain)
```

## Replay by Timestamp

Use `app.as_of(timestamp)` to get a proxy that reconstitutes aggregates as they
were at a given point in time:

```ruby
pizza = Pizza.create(name: "Original", style: "Classic")
snapshot_time = Time.now

# ... some time passes ...
Pizza.rename(pizza: pizza.id, name: "Updated")

# Travel back in time
past_pizza = app.as_of(snapshot_time).find("Pizza", pizza.id)
past_pizza.name  # => "Original"

# Current state is unchanged
Pizza.find(pizza.id).name  # => "Updated"
```

## Replay by Version

Use `app.at_version` to reconstitute an aggregate at a specific event version:

```ruby
pizza = Pizza.create(name: "V1", style: "Classic")  # version 1
Pizza.rename(pizza: pizza.id, name: "V2")            # version 2
Pizza.rename(pizza: pizza.id, name: "V3")            # version 3

v1 = app.at_version("Pizza", pizza.id, version: 1)
v1.name  # => "V1"

v2 = app.at_version("Pizza", pizza.id, version: 2)
v2.name  # => "V2"
```

`reconstitute_at_version` is an alias for `at_version`:

```ruby
app.reconstitute_at_version("Pizza", pizza.id, version: 1)
```

## Direct EventStore Access

The event store is available on the runtime for direct queries:

```ruby
store = app.event_store

# All events in a stream
store.read_stream("Pizza-#{pizza.id}")

# Events up to a timestamp
store.read_stream_until("Pizza-#{pizza.id}", timestamp: 1.hour.ago)

# Events up to a version
store.read_stream_to_version("Pizza-#{pizza.id}", version: 2)

# Current version of a stream
store.stream_version("Pizza-#{pizza.id}")  # => 3
```

Each record is a Hash with:
- `:stream_id` — e.g. `"Pizza-abc123"`
- `:version` — monotonically increasing integer per stream
- `:event_type` — e.g. `"CreatedPizza"`
- `:event` — the original domain event object
- `:occurred_at` — the event's `Time` timestamp

## How It Works

1. Every domain event published on the event bus is automatically appended to
   the in-memory `EventStore` via a global listener.
2. Events are grouped into streams keyed by `"AggregateType-id"`.
3. Each event gets an incrementing version number within its stream.
4. `as_of` and `at_version` filter the stream, then replay events sequentially
   to reconstruct the aggregate by applying event attributes cumulatively.

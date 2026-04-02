# Aggregate Snapshots

Aggregate snapshots speed up reconstitution in event-sourced domains by
periodically saving a point-in-time copy of aggregate state. Instead of
replaying every event from the beginning, reconstitution starts from the
latest snapshot and only applies events that came after it.

## Quick Start

```ruby
require "hecks/extensions/snapshots"

domain = Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String

    command "CreatePizza" do
      attribute :name, String
    end

    command "UpdatePizza" do
      attribute :pizza, String
      attribute :name, String
    end

    # Apply blocks define how to reconstitute from events
    apply "CreatedPizza" do |_aggregate, data|
      PizzasDomain::Pizza.new(id: data["aggregate_id"], name: data["name"])
    end

    apply "UpdatedPizza" do |aggregate, data|
      PizzasDomain::Pizza.new(id: aggregate.id, name: data["name"] || aggregate.name)
    end
  end
end

app = Hecks.load(domain)
app.extend(:snapshots, threshold: 50)  # snapshot every 50 events
```

## Snapshot Store

The `MemorySnapshotStore` provides the port interface:

```ruby
store = Hecks::Snapshots::MemorySnapshotStore.new

# Save a snapshot
store.save_snapshot("Pizza", pizza_id, version: 50, state: { id: pizza_id, name: "Margherita" })

# Load the latest snapshot
snap = store.load_snapshot("Pizza", pizza_id)
snap[:version]  # => 50
snap[:state]    # => { id: "...", name: "Margherita" }
snap[:taken_at] # => Time

# Clear all snapshots
store.clear
```

After wiring the extension, the store is available via `Hecks.snapshot_store`.

## Reconstitution

Rebuild an aggregate from snapshot + events:

```ruby
aggregate = Hecks::Snapshots::Reconstitution.reconstitute(
  PizzasDomain::Pizza, pizza_id,
  snapshot_store: Hecks.snapshot_store,
  event_recorder: recorder
)
```

The reconstitution flow:
1. Load the latest snapshot for the aggregate (if any)
2. Fetch events after the snapshot version
3. Fold each event through the matching `apply` block
4. Return the rebuilt aggregate

## Auto-Snapshot

The extension automatically snapshots after a configurable number of events
per aggregate stream. Default threshold is 100.

```ruby
# Snapshot every 100 events (default)
app.extend(:snapshots)

# Snapshot every 20 events
app.extend(:snapshots, threshold: 20)
```

## DSL: Apply Blocks

Define `apply` blocks inside an aggregate to specify how each event type
modifies aggregate state during reconstitution:

```ruby
aggregate "Order" do
  attribute :status, String
  attribute :total, Float

  apply "PlacedOrder" do |_aggregate, data|
    OrdersDomain::Order.new(
      id: data["aggregate_id"],
      status: "placed",
      total: data["total"].to_f
    )
  end

  apply "CompletedOrder" do |aggregate, data|
    OrdersDomain::Order.new(
      id: aggregate.id,
      status: "completed",
      total: aggregate.total
    )
  end
end
```

The first argument is the current aggregate (nil for create events).
The second argument is the event data as a Hash with string keys.
The block must return a new aggregate instance.

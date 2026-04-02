# Projections — Read Models from Events

Projections build denormalized read model state by replaying domain events
through projection functions. Views declared with `from_stream` automatically
replay historical events before subscribing to live ones.

## Defining a View with Projections

```ruby
Hecks.domain "Orders" do
  aggregate "Order" do
    attribute :item, String
    attribute :quantity, Integer

    command "PlaceOrder" do
      attribute :item, String
      attribute :quantity, Integer
    end
  end

  view "OrderSummary" do
    from_stream "orders"

    project("PlacedOrder") do |event, state|
      count = (state[:total_orders] || 0) + 1
      qty   = (state[:total_quantity] || 0) + event.quantity
      state.merge(total_orders: count, total_quantity: qty)
    end
  end
end
```

## Querying a View

Each view becomes a module under the domain namespace with a `.current` method:

```ruby
app = Hecks.boot(__dir__)

Order.place(item: "Widget", quantity: 3)
Order.place(item: "Gadget", quantity: 2)

OrdersDomain::OrderSummary.current
# => { total_orders: 2, total_quantity: 5 }
```

## How `from_stream` Works

When a view declares `from_stream`, the runtime:

1. Captures a snapshot of the event bus history at boot time
2. Passes the snapshot to `ProjectionRebuilder.replay`, which folds each
   matching event through the projection functions
3. The resulting state becomes the view's initial state
4. The view then subscribes to live events for ongoing updates

Without `from_stream`, the view starts with an empty state and only
processes events published after boot.

## Using ProjectionRebuilder Directly

You can replay events through projections outside the view system:

```ruby
projections = {
  "PlacedOrder" => proc { |event, state|
    state.merge(count: (state[:count] || 0) + 1)
  }
}

events = app.event_bus.events
state = Hecks::ProjectionRebuilder.replay(events, projections)
# => { count: 3 }
```

## Multiple Projections per View

A view can project multiple event types:

```ruby
view "Dashboard" do
  from_stream "all"

  project("PlacedOrder") do |event, state|
    state.merge(orders: (state[:orders] || 0) + 1)
  end

  project("CancelledOrder") do |event, state|
    state.merge(cancellations: (state[:cancellations] || 0) + 1)
  end
end
```

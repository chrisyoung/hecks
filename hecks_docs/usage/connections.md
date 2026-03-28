# Domain Connections

Everything outside the domain boundary is a **connection**. Two things cross:
data (`persist_to`) and events (`listens_to` / `sends_to`).

## persist_to — data crosses the boundary

```ruby
app = Hecks.boot(__dir__) do
  persist_to :sqlite
end
```

Supported adapters: `:memory` (default), `:sqlite`, `:postgres`, `:mysql`.

With options:

```ruby
app = Hecks.boot(__dir__) do
  persist_to :sqlite, database: "production.db"
end
```

The `adapter:` keyword argument still works as shorthand:

```ruby
app = Hecks.boot(__dir__, adapter: :sqlite)
```

## sends_to — events leave the boundary

Forward all domain events to an external adapter (e.g., email, Kafka, logging):

```ruby
app = Hecks.boot(__dir__) do
  sends_to :notifications, SendgridAdapter.new
end
```

The handler can be any object that responds to `#call(event)` or `#publish(event)`,
or a block:

```ruby
app = Hecks.boot(__dir__) do
  sends_to(:audit) { |event| AuditLog.record(event) }
end
```

## listens_to — events enter the boundary

Subscribe to events from another domain. The source domain must be booted first:

```ruby
delivery_app = Hecks.boot(delivery_dir)
pizza_app = Hecks.boot(pizza_dir) do
  listens_to DeliveryDomain
end

pizza_app.on("DeliveredOrder") do |event|
  # React to events from the Delivery domain
end
```

## Inspecting connections

Every domain module exposes its connection configuration:

```ruby
PizzasDomain.connections
# => { persist: { type: :sqlite }, listens: [], sends: [{ name: :audit, handler: #<Proc> }] }
```

Each domain module also exposes its event bus for cross-domain wiring:

```ruby
PizzasDomain.event_bus  # => #<Hecks::Services::EventBus>
```

# Domain Connections

Everything outside the domain boundary is a **connection**. One verb: `extend`.

## Persistence

```ruby
app = Hecks.boot(__dir__) do
  extend :sqlite
end
```

Supported adapters: `:memory` (default), `:sqlite`, `:postgres`, `:mysql`.

With options:

```ruby
app = Hecks.boot(__dir__) do
  extend :sqlite, database: "production.db"
end
```

Named connections for CQRS:

```ruby
app = Hecks.boot(__dir__) do
  extend :sqlite, as: :write
  extend :sqlite, as: :read, database: "read.db"
end
```

The `adapter:` keyword argument still works as shorthand:

```ruby
app = Hecks.boot(__dir__, adapter: :sqlite)
```

## Outbound events

Forward all domain events to an external handler:

```ruby
app = Hecks.boot(__dir__) do
  extend :slack, webhook: ENV["SLACK_URL"]
  extend :audit, ->(event) { AuditLog.record(event) }
  extend(:logs) { |event| puts event }
end
```

## Cross-domain events

Subscribe to events from another domain. The source domain must be booted first:

```ruby
delivery_app = Hecks.boot(delivery_dir)
pizza_app = Hecks.boot(pizza_dir) do
  extend DeliveryDomain
end

pizza_app.on("DeliveredOrder") do |event|
  # React to events from the Delivery domain
end
```

## Middleware

```ruby
app = Hecks.boot(__dir__) do
  extend :tenancy
  extend :auth
end
```

## Inspecting connections

```ruby
PizzasDomain.connections
# => { persist: { default: { type: :sqlite } }, listens: [], sends: [], extensions: [] }

PizzasDomain.event_bus  # => #<Hecks::EventBus>
```

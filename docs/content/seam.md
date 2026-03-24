A domain has a boundary. **Ports are the only way through it.**

```ruby
# The domain — pure structure and intent
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end

# Ports — how the domain connects to everything else
PizzasDomain.persist_to(:sql)
PizzasDomain.port(DeliveryDomain)
PizzasDomain.port(:notifications, SendgridAdapter.new)
PizzasDomain.port(:tenant, ColumnTenant.new)
```

Three interfaces, one concept:

- **Class methods** — outside world commands the domain: `Pizza.create(name: "Margherita")`
- **Instance methods** — domain objects talk to each other: `pizza.deliver`
- **Ports** — domain reaches the outside world: events, persistence, other domains

Domains don't call each other's commands. They subscribe to each other's events through ports:

```ruby
PizzasDomain.port(DeliveryDomain)   # Pizza events visible to Delivery
DeliveryDomain.port(PizzasDomain)   # Delivery events visible to Pizza
```

Pizza emits `PizzaReady`. Delivery reacts with `ScheduleDelivery`. Delivery emits `DeliveryCompleted`. Pizza reacts with `MarkDelivered`. Two domains, zero coupling.

A port is just a block of code plugged into a named slot:

```ruby
PizzasDomain.port(:notifications) do |event|
  Sendgrid.send(to: event.email, body: "Your pizza is ready")
end
```

No adapter class needed unless you want one. Persistence is a port. Notifications is a port. Another domain is a port. Tenancy is a port. Everything outside the boundary is a port.

*Know DDD? See [how Hecks maps to DDD patterns](docs/ddd.md).*

*Love hexagonal architecture? See [how Hecks implements ports and adapters](docs/hexagonal.md).*

*Using Rails? See [how ActiveHecks bridges domain objects and Rails](docs/active_hecks.md).*

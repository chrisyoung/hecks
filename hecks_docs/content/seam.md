A domain has a boundary. **Extensions are the only way through it.**

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

# Extensions — how the domain connects to everything else
PizzasDomain.extend(:sql)
PizzasDomain.extend(DeliveryDomain)
PizzasDomain.extend(:notifications, SendgridAdapter.new)
PizzasDomain.extend(:tenant, ColumnTenant.new)
```

Three interfaces, one concept:

- **Class methods** — outside world commands the domain: `Pizza.create(name: "Margherita")`
- **Instance methods** — domain objects talk to each other: `pizza.deliver`
- **Extensions** — domain reaches the outside world: events, persistence, other domains

Domains don't call each other's commands. They subscribe to each other's events through extensions:

```ruby
PizzasDomain.extend(DeliveryDomain)   # Pizza events visible to Delivery
DeliveryDomain.extend(PizzasDomain)   # Delivery events visible to Pizza
```

Pizza emits `PizzaReady`. Delivery reacts with `ScheduleDelivery`. Delivery emits `DeliveryCompleted`. Pizza reacts with `MarkDelivered`. Two domains, zero coupling.

An extension is just a block of code plugged into a named slot:

```ruby
PizzasDomain.extend(:notifications) do |event|
  Sendgrid.send(to: event.email, body: "Your pizza is ready")
end
```

No adapter class needed unless you want one. Persistence is an extension. Notifications is an extension. Another domain is an extension. Tenancy is an extension. Everything outside the boundary is an extension.

*Know DDD? See [how Hecks maps to DDD patterns](docs/ddd.md).*

*Love hexagonal architecture? See [how Hecks implements ports and adapters](docs/hexagonal.md).*

*Using Rails? See [how ActiveHecks bridges domain objects and Rails](docs/active_hecks.md).*

# Process Managers (Event-Driven Sagas)

Process managers are event-driven state machines that subscribe to the event bus,
transition through named states, and dispatch commands in response to domain events.

## DSL

Use `on` inside a `saga` block to define event-driven transitions:

```ruby
domain = Hecks.domain "OrderManagement" do
  aggregate "Order" do
    attribute :item, String
    attribute :correlation_id, String

    command "PlaceOrder" do
      attribute :item, String
      attribute :correlation_id, String
    end

    command "ShipOrder" do
      attribute :item, String
      attribute :correlation_id, String
    end

    command "CompleteOrder" do
      attribute :item, String
      attribute :correlation_id, String
    end
  end

  saga "OrderProcess" do
    on "OrderPlaced",
      dispatch: "ShipOrder",
      from: "started",
      to: "shipping"

    on "OrderShipped",
      dispatch: "CompleteOrder",
      from: "shipping",
      to: "completed"
  end
end
```

## Starting a Process Manager

```ruby
app = Hecks.load(domain)

# Start a process manager instance (state begins at "started")
instance = OrderManagementDomain.start_order_process(
  correlation_id: "order-42",
  item: "Widget"
)
instance[:state]          # => "started"
instance[:correlation_id] # => "order-42"
```

## Event-Driven Transitions

When a matching event is published on the bus, the process manager:
1. Finds the instance by `correlation_id` on the event
2. Checks the `from:` state guard (if present)
3. Dispatches the declared command
4. Advances the instance to the `to:` state

Events must respond to `correlation_id` (method or hash key).

## State Guards

Transitions only fire when the instance is in the declared `from` state:

```ruby
on "OrderShipped",
  dispatch: "CompleteOrder",
  from: "shipping",    # Only fires when state == "shipping"
  to: "completed"
```

## SagaStore Correlation Lookup

```ruby
store = Hecks::SagaStore.new
store.save("pm_abc", { correlation_id: "order-42", state: "shipping" })
store.find_by_correlation("order-42")  # => the instance hash
```

## Mixing Imperative Steps and Event-Driven Transitions

A single saga can combine both styles:

```ruby
saga "TicketProcess" do
  step "CreateTicket", on_success: "TicketCreated"

  on "TicketCreated",
    dispatch: "AssignTicket",
    from: "started",
    to: "assigned"
end
```

## Backward Compatibility

Existing imperative sagas with `step`/`compensate` continue to work unchanged.
The `event_driven?` predicate on the Saga IR tells you which mode is in use:

```ruby
domain.sagas.first.event_driven?  # true if transitions present
domain.sagas.first.steps           # imperative steps (may be empty)
domain.sagas.first.transitions     # event-driven transitions (may be empty)
```

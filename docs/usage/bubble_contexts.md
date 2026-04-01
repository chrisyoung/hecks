# Bubble Contexts

Bubble contexts define named sub-boundaries within a domain, grouping
existing aggregates under a logical context. They act as anti-corruption
layers, presenting a simplified view of a subset of the domain.

## DSL

```ruby
Hecks.domain "ECommerce" do
  aggregate "Order" do
    attribute :total, Integer
    command "CreateOrder" do
      attribute :total, Integer
    end
  end

  aggregate "Shipment" do
    attribute :tracking_number, String
    command "CreateShipment" do
      attribute :tracking_number, String
    end
  end

  aggregate "Payment" do
    attribute :amount, Float
    command "CreatePayment" do
      attribute :amount, Float
    end
  end

  bubble_context "Fulfillment" do
    aggregate "Order"
    aggregate "Shipment"
  end

  bubble_context "Billing" do
    aggregate "Payment"
  end
end
```

## Querying bubble contexts

```ruby
domain = Hecks.domain "ECommerce" do
  # ... aggregates and bubble_contexts as above
end

domain.bubble_contexts.map(&:name)
# => ["Fulfillment", "Billing"]

domain.bubble_contexts.first.aggregate_names
# => ["Order", "Shipment"]
```

## Round-trip serialization

Bubble contexts survive DSL round-trips through `DslSerializer`:

```ruby
source = Hecks::DslSerializer.new(domain).serialize
restored = eval(source)
restored.bubble_contexts.first.name  # => "Fulfillment"
```

## Notes

- Aggregates are referenced by name; they must be defined elsewhere in
  the same domain.
- An aggregate can appear in multiple bubble contexts.
- Bubble contexts are purely organizational metadata -- they do not
  affect runtime behavior or code generation.
- The Web Explorer's IRIntrospector exposes `bubble_contexts` and
  `bubble_context_for(aggregate_name)` for UI rendering.

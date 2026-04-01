# Bubble Contexts

Bubble contexts define bounded context boundaries within a single domain.
They group related aggregates together, marking logical sub-boundaries
useful for documentation, visualization, and identifying future domain
extraction candidates.

## Basic Usage

```ruby
Hecks.domain "ECommerce" do
  aggregate "Order" do
    attribute :name, String
    command("CreateOrder") { attribute :name, String }
  end

  aggregate "Shipment" do
    attribute :tracking, String
    command("CreateShipment") { attribute :tracking, String }
  end

  aggregate "Invoice" do
    attribute :amount, Float
    command("CreateInvoice") { attribute :amount, Float }
  end

  bubble_context "Fulfillment" do
    aggregate "Order"
    aggregate "Shipment"
    description "Handles order fulfillment and shipping"
  end

  bubble_context "Billing" do
    aggregate "Invoice"
    description "Handles invoicing and payments"
  end
end
```

## Accessing Bubble Contexts

```ruby
domain = Hecks.domain("ECommerce") { ... }

domain.bubble_contexts.each do |ctx|
  puts "#{ctx.name}: #{ctx.aggregate_names.join(', ')}"
  puts "  #{ctx.description}" if ctx.description
end
# Fulfillment: Order, Shipment
#   Handles order fulfillment and shipping
# Billing: Invoice
#   Handles invoicing and payments
```

## Validation

Bubble contexts validate that all referenced aggregate names exist in the
domain. Referencing an unknown aggregate raises a `Hecks::ValidationError`:

```ruby
Hecks.domain "Bad" do
  aggregate("Order") { ... }

  bubble_context "Fulfillment" do
    aggregate "NonExistent"  # => Hecks::ValidationError
  end
end
```

## Empty Contexts

A bubble context without a block creates an empty placeholder:

```ruby
bubble_context "FutureArea"
# ctx.aggregate_names => []
# ctx.description     => nil
```

## When to Use

- **Large domains** with 5+ aggregates that cluster into distinct areas
- **Documentation** to communicate team boundaries or area ownership
- **Visualization** to group aggregates in Mermaid diagrams
- **Extraction candidates** when a bubble context grows into its own domain

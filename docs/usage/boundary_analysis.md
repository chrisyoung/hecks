# Boundary Analysis (Big Ball of Mud Detection)

Hecks automatically warns when your domain model shows signs of the
"Big Ball of Mud" anti-pattern -- excessive coupling between aggregates
that erodes bounded context boundaries.

## What gets checked

### Reference Density (threshold: 2.0)

The ratio of total cross-aggregate references to the number of aggregates.
A density above 2.0 means every aggregate averages more than two outgoing
references, suggesting the domain is over-connected.

### Hub Detection (threshold: 50%)

Any aggregate that receives more than 50% of all inbound references is
flagged as a hub. Hubs often become "God Objects" that every other
aggregate depends on.

### Cycle Detection (DFS)

Circular reference chains like A -> B -> C -> A are detected using
depth-first search. Cycles make it impossible to reason about aggregate
boundaries and ownership.

### Fan-Out (threshold: 4)

Any single aggregate with 4 or more outgoing references is flagged.
High fan-out suggests the aggregate has too many responsibilities.

## Example

```ruby
Hecks.domain "Ecommerce" do
  aggregate "Order" do
    reference_to "Customer"
    reference_to "Product"
    reference_to "Warehouse"
    reference_to "ShippingMethod"
    command("PlaceOrder") { attribute :name, String }
  end

  aggregate "Customer" do
    reference_to "Order"
    reference_to "Product"
    command("CreateCustomer") { attribute :name, String }
  end

  aggregate "Product" do
    reference_to "Warehouse"
    command("CreateProduct") { attribute :name, String }
  end

  aggregate "Warehouse" do
    command("CreateWarehouse") { attribute :name, String }
  end

  aggregate "ShippingMethod" do
    command("CreateShippingMethod") { attribute :name, String }
  end
end
```

Running `hecks build` will show warnings like:

```
WARNING: Order has 4 outgoing references (threshold: 4). This aggregate may have too many responsibilities -- consider splitting it.
WARNING: Reference cycle detected: Customer -> Order -> Customer. Break the cycle with a domain event or policy instead of a direct reference.
```

## How to fix

- **High density**: Split the domain into separate bounded contexts
- **Hub aggregates**: Extract a shared kernel or anti-corruption layer
- **Cycles**: Replace one direction with a domain event or policy
- **High fan-out**: Split the aggregate into smaller, focused aggregates

All boundary analysis findings are **warnings** (non-blocking). Your domain
will still compile and build, but the warnings highlight structural risks.

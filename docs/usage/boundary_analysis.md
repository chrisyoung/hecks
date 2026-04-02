# Boundary Analysis

Validation rules that analyze the reference topology between aggregates.

## BoundaryAnalysis

Detects three topology problems:

### Reference Density
Warns when the ratio of actual references to maximum possible references exceeds 0.5.

### Hub Aggregates
Warns when an aggregate is referenced by 3 or more other aggregates.

```ruby
# Hub warning triggered:
aggregate("User") { ... }       # referenced by Team, Order, Comment
aggregate("Team") { reference_to "User"; ... }
aggregate("Order") { reference_to "User"; ... }
aggregate("Comment") { reference_to "User"; ... }
# Warning: "User is a hub aggregate (referenced by 3 others)"
```

### Reference Cycles
Uses depth-first search to detect cycles in the reference graph.

```ruby
# Cycle detected:
aggregate("A") { reference_to "B"; ... }
aggregate("B") { reference_to "C"; ... }
aggregate("C") { reference_to "A"; ... }
# Warning: "Reference cycle: A -> B -> C -> A"
```

## FanOut (4+ refs)

Warns when a single aggregate references 4 or more other aggregates.

```ruby
aggregate("Order") do
  reference_to "Pizza"
  reference_to "Customer"
  reference_to "Delivery"
  reference_to "Payment"    # 4th reference triggers warning
end
```

## Running

```bash
hecks validate
hecks validate --format json
```

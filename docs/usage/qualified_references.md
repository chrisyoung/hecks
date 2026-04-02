# Qualified Reference Paths

## Overview

`reference_to` supports qualified paths with 1, 2, or 3 segments to precisely
target entities across aggregate and domain boundaries.

## Syntax

### 1-segment (local lookup)

```ruby
reference_to "Pizza"      # looks up in current aggregate, then domain aggregates
```

### 2-segment (aggregate::entity)

```ruby
reference_to "Pizza::Topping"   # targets Topping entity inside Pizza aggregate
```

If the first segment matches a known aggregate in the domain, the reference
targets that aggregate's entity or value object. Otherwise, it is treated as a
cross-domain reference (`Domain::Aggregate`).

### 3-segment (domain::aggregate::entity)

```ruby
reference_to "Ordering::Pizza::Topping"   # domain=Ordering, aggregate=Pizza, entity=Topping
```

Always interpreted as a cross-context reference.

## Classification

After the domain is built, `classify_references` resolves each reference:

| Path | Kind | Example |
|------|------|---------|
| 1-segment, matches local entity/VO | `:composition` | `reference_to "Topping"` inside Pizza |
| 1-segment, matches another aggregate | `:aggregation` | `reference_to "Customer"` |
| 2-segment, first is known aggregate | `:composition` or `:aggregation` | `reference_to "Pizza::Topping"` |
| 2-segment, first is unknown | `:cross_context` | `reference_to "Billing::Invoice"` |
| 3-segment | `:cross_context` | `reference_to "Ordering::Pizza::Topping"` |

## Example

```ruby
Hecks.domain "Shop" do
  aggregate "Pizza" do
    attribute :name, String
    entity("Topping") { attribute :label, String }
    command("CreatePizza") { attribute :name, String }
  end

  aggregate "Order" do
    attribute :qty, Integer
    reference_to "Pizza::Topping"          # qualified intra-domain
    reference_to "Billing::Invoice"        # cross-domain
    command("PlaceOrder") { attribute :qty, Integer }
  end
end
```

## Validation

- 2-segment paths with a known aggregate validate that the entity/VO exists
- Unknown aggregate in first segment is treated as cross-domain (validated at boot)
- Error messages include the full qualified path and available types

## DslSerializer

Round-trips preserve qualified paths:

```ruby
dsl = Hecks::DslSerializer.new(domain).serialize
# => reference_to "Pizza::Topping"
# => reference_to "Billing::Invoice"
```

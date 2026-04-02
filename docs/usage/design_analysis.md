# Design Analysis (Conceptual Contours)

Hecks includes aggregate design analysis rules inspired by Eric Evans'
*Conceptual Contours* pattern from Domain-Driven Design. These are
non-blocking **warnings** that surface during `hecks validate` and
`hecks build` to help you keep aggregates focused and cohesive.

## Rules

| Rule                  | Threshold                              | Message |
|-----------------------|----------------------------------------|---------|
| TooManyAttributes     | 8+ root attributes                     | "consider extracting value objects" |
| TooManyValueObjects   | 5+ value objects                       | "consider splitting the aggregate" |
| MissingLifecycle      | status/state attribute, no lifecycle   | "consider adding a lifecycle definition" |
| CohesionAnalysis      | commands touch < 50% of attributes     | "has low cohesion" |
| GodAggregate          | 8+ attrs AND 8+ cmds AND 3+ VOs       | "strongly consider decomposing" |

## Example

```ruby
Hecks.domain "Ecommerce" do
  aggregate "Order" do
    attribute :name, String
    attribute :email, String
    attribute :phone, String
    attribute :address, String
    attribute :city, String
    attribute :state, String
    attribute :zip, String
    attribute :status, String

    command "PlaceOrder" do
      attribute :name, String
    end
  end
end
```

Running `hecks validate` would produce:

```
WARNING: Order has 8 attributes -- consider extracting value objects
WARNING: Order has a status attribute but no lifecycle -- consider adding a lifecycle definition
WARNING: Order has low cohesion -- commands touch 1/8 attributes
```

## Fixing warnings

- **TooManyAttributes** -- Group related fields into value objects:
  `value_object("Address") { attribute :city, String; attribute :state, String; attribute :zip, String }`

- **TooManyValueObjects** -- Split the aggregate into two or more
  smaller aggregates connected by `reference_to`.

- **MissingLifecycle** -- Add a lifecycle via attribute block:
  `attribute :status, String, default: "open" do transition "CloseOrder" => "closed", from: "open" end`

- **CohesionAnalysis** -- Ensure commands reference the attributes they
  need, or split unrelated attributes into a separate aggregate.

- **GodAggregate** -- This fires only when all three thresholds are
  exceeded simultaneously. Decompose the aggregate by extracting
  cohesive subsets into their own aggregates.

# Events View

Browse all domain events defined in the Bluebook IR from the Web Explorer.

## Access

Navigate to `/events` in the Web Explorer sidebar (under **System**), or visit
`http://localhost:9292/events` directly.

## What it shows

A table listing every domain event across all aggregates:

| Column      | Description                                      |
|-------------|--------------------------------------------------|
| Event       | PascalCase event name (e.g. `CreatedPizza`)      |
| Aggregate   | The aggregate that emits the event (linked)       |
| Attributes  | Comma-separated attribute names carried by event  |

## Example

Given a pizza domain:

```ruby
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
    command "RatePizza" do
      attribute :pizza_id, String
      attribute :stars, Integer
    end
  end
end
```

The `/events` page displays:

```
Events (2)
Event           Aggregate   Attributes
CreatedPizza    Pizza       name
RatedPizza      Pizza       pizza_id, stars
```

## Multi-domain

When serving multiple domains, events from all domains appear in a single
combined table. The aggregate link routes to the correct domain-scoped
aggregate index.

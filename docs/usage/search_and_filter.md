# Search and Filter (HEC-261)

Filter and search aggregate records in the Web Explorer index view.

## URL Convention

```
GET /pizzas?filter[style]=Classic&q=marg
```

- `filter[attr]=value` — exact match on any filterable attribute
- `q=term` — case-insensitive substring search across all string/enum attributes
- Filters and search combine with AND logic

## Filterable Attributes

`IRIntrospector#filterable_attributes` returns attributes with String type or enum constraints. These appear as filter controls in the index view.

## RuntimeBridge API

```ruby
bridge = Hecks::WebExplorer::RuntimeBridge.new(mod)
bridge.search_and_filter("Pizza",
  filters: { style: "Classic" },
  query: "marg",
  filterable: [:name, :style]
)
# => [#<Pizza name="Margherita" style="Classic">]
```

## UI

The index page shows a filter bar above the table with:
- A text input for free-text search (`q=`)
- Per-attribute inputs: text fields for strings, dropdowns for enums
- "Filter" button to apply, "Clear" link to reset

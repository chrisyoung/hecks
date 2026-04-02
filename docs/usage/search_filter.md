# Web Explorer Search and Filter

Search and filter aggregate records in the Web Explorer UI.

## Full-Text Search

Add `q=` to any aggregate index URL to search across all visible attributes:

```
GET /pizzas?q=margherita
GET /pizzas?q=classic
```

Search is case-insensitive substring matching. It checks every visible
attribute on the aggregate.

## Attribute Filters

Use `filter[attr]=value` to filter by specific attributes:

```
GET /pizzas?filter[style]=Classic
GET /orders?filter[status]=placed
```

Filters use `klass.where()` when ad-hoc queries are enabled (exact match).
Otherwise they fall back to in-memory string comparison.

## Combining Search and Filter

Search and filter can be combined in a single request:

```
GET /pizzas?q=marg&filter[style]=Classic
```

Filters are applied first, then the search narrows the filtered results.

## UI

The index page automatically shows a search/filter bar when filterable
attributes exist. Enum attributes render as dropdowns; string attributes
render as text inputs. A "Clear" link resets all filters.

## Programmatic Usage (RuntimeBridge)

```ruby
bridge = Hecks::WebExplorer::RuntimeBridge.new(domain_module)

# Search only
bridge.search_and_filter("Pizza", query: "marg", attributes: [:name, :style])

# Filter only
bridge.search_and_filter("Pizza", filters: { style: "Classic" }, attributes: [:name])

# Combined
bridge.search_and_filter("Pizza",
  filters: { style: "Classic" },
  query: "marg",
  attributes: [:name, :style, :description])
```

## IRIntrospector Helper

```ruby
ir = Hecks::WebExplorer::IRIntrospector.new(domain)
agg = ir.find_aggregate("Pizza")
ir.filterable_attributes(agg)  # => attributes with String type or enum
```

Returns attributes suitable for filter UI generation. Enum attributes
get dropdown selectors; string attributes get free-text filter inputs.

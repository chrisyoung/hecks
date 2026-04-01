# no_crud -- Opt-in CRUD Control

By default every aggregate gets full CRUD methods (create, update, destroy,
find, all, count). Use `no_crud` to disable the **write** methods while
keeping reads available.

## When to use

- Read-only projections or audit logs that should never be mutated through
  the domain API
- Aggregates whose writes are exclusively driven by custom commands

## DSL

```ruby
Hecks.domain "Warehouse" do
  aggregate "Widget" do
    attribute :name, String
    command("CreateWidget") { attribute :name, String }
  end

  aggregate "AuditLog" do
    no_crud                       # no create/update/destroy
    attribute :message, String
    command("RecordEntry") { attribute :message, String }
  end
end
```

## What changes

| Capability              | Default | `no_crud` |
|-------------------------|---------|-----------|
| `.find(id)`             | yes     | yes       |
| `.all`                  | yes     | yes       |
| `.count`                | yes     | yes       |
| `.create(**attrs)`      | yes     | **no**    |
| `#destroy`              | yes     | **no**    |
| `#save` (update)        | yes     | **no**    |
| Custom commands          | yes     | yes       |
| HTTP DELETE route        | yes     | **no**    |
| RPC delete method        | yes     | **no**    |
| OpenAPI delete path      | yes     | **no**    |

## Checking at runtime

```ruby
aggregate = domain.aggregates.find { |a| a.name == "AuditLog" }
aggregate.auto_crud?  # => false
```

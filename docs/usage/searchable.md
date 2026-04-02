# Searchable Attribute Tag

The `:searchable` capability tag marks one or more aggregate fields for full-text
search. Tagged fields are indexed in the database (GIN/tsvector on Postgres) and
a `search(term)` method is generated on the repository.

## DSL

In your `HecksagonBluebook` (or inline hecksagon block), tag attributes on an
aggregate using the fluent `capability.field.searchable` syntax:

```ruby
Hecks.hecksagon do
  aggregate "Pizza" do
    capability.name.searchable
    capability.description.searchable
  end
end
```

Multiple fields can be tagged. Tags can be chained with others:

```ruby
aggregate "Customer" do
  capability.notes.searchable.pii  # searchable AND pii in one chain
end
```

## IR Query

`Hecksagon#searchable_fields(aggregate_name)` returns an array of field names
tagged `:searchable` for the given aggregate:

```ruby
hex.searchable_fields("Pizza")  # => ["name", "description"]
```

## Generated `search(term)` Method

When `SqlBoot.setup` or `MongoBoot.setup` receives a hecksagon with searchable
fields, the generated repository class includes a `search(term)` method.

### SQL (Sequel / SQLite / Postgres / MySQL)

Uses `Sequel.ilike` (case-insensitive LIKE) across all searchable fields joined
with `OR`. Works on every Sequel-backed adapter without a text extension:

```ruby
Pizza.search("margherita")
# => [#<Pizza name="Margherita" ...>]
```

### MongoDB

Uses a MongoDB `$text` search (requires a text index created at boot):

```ruby
Pizza.search("margherita")
# => [#<Pizza name="Margherita" ...>]
```

## SQL Schema Index

For Postgres, `SqlMigrationGenerator` emits a GIN tsvector index. Pass
`adapter_type: :postgres` to `generate`:

```ruby
gen = Hecks::Generators::SQL::SqlMigrationGenerator.new(domain, hecksagon: hex)
puts gen.generate(adapter_type: :postgres)

# CREATE TABLE pizzas (
#   ...
# );
#
# CREATE INDEX idx_pizzas_fts ON pizzas
#   USING gin(to_tsvector('english', coalesce(name::text, '') || ' ' || coalesce(description::text, '')));
```

For SQLite or MySQL, no index is emitted — `search(term)` uses LIKE at query time.

## Boot-time Index Creation

When booting with Postgres and a hecksagon, the GIN index is created automatically:

```ruby
hex = Hecks.hecksagon do
  adapter :postgres, database: "myapp"
  aggregate "Pizza" do
    capability.name.searchable
    capability.description.searchable
  end
end

app = Hecks.load(domain, hecksagon: hex)
# => GIN index created on pizzas table
```

# Indexed Attribute Tag

The `:indexed` tag marks aggregate attributes for database indexing. When a hecksagon declares an attribute as indexed, Hecks automatically emits `CREATE INDEX` statements in SQL migrations and creates `{ field => 1 }` indexes in MongoDB.

## DSL Syntax

### With `capability.` prefix

```ruby
Hecks.hecksagon do
  aggregate "Order" do
    capability.created_at.indexed
    capability.status.indexed
  end
end
```

### Bare attribute shorthand

```ruby
Hecks.hecksagon do
  aggregate "Order" do
    created_at.indexed
    status.indexed
  end
end
```

### Chaining with other tags

Tags are additive. Chain `:indexed` after any other tag:

```ruby
Hecks.hecksagon do
  aggregate "Customer" do
    ssn.privacy.indexed    # tagged both :privacy and :indexed
  end
end
```

## IR Query

Use `indexed_attributes_for` to retrieve indexed attribute names from the hecksagon IR:

```ruby
hex = Hecks.hecksagon do
  aggregate "Order" do
    capability.created_at.indexed
    capability.status.indexed
    capability.total.audit     # not indexed
  end
end

hex.indexed_attributes_for("Order")
# => ["created_at", "status"]
```

## SQL Output

Pass the hecksagon to `SqlMigrationGenerator` to emit `CREATE INDEX` after the `CREATE TABLE`:

```ruby
domain = Hecks.domain "Shop" do
  aggregate "Order" do
    attribute :status, String
    attribute :created_at, String
    command "PlaceOrder" do
      attribute :status, String
    end
  end
end

hex = Hecks.hecksagon do
  aggregate "Order" do
    capability.created_at.indexed
  end
end

gen = Hecks::Generators::SQL::SqlMigrationGenerator.new(domain, hecksagon: hex)
puts gen.generate
```

Output:

```sql
CREATE TABLE orders (
  id VARCHAR(36) PRIMARY KEY,
  status VARCHAR(255),
  created_at VARCHAR(255)
);

CREATE INDEX idx_orders_created_at ON orders(created_at);
```

The `generate_sql` CLI command picks up `Hecks.last_hecksagon` automatically.

## MongoDB

When calling `MongoBoot.setup` with a hecksagon, Hecks calls `create_one` on each indexed attribute:

```ruby
MongoBoot.setup(domain, client, hecksagon: hex)
# => creates { "created_at" => 1 } index on the orders collection
```

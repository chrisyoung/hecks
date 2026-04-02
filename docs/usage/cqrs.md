# CQRS -- Command Query Responsibility Segregation

Hecks supports separating write (command) and read (query) repositories.
When CQRS is active, commands route to the write repository while queries,
scopes, and read methods (`find`, `all`, `where`) route to a separate
read store. When no read store is registered, everything uses a single
adapter (backward compatible).

## Programmatic Activation

Enable CQRS for an aggregate after boot:

```ruby
domain = Hecks.domain "Catalog" do
  aggregate "Product" do
    attribute :name, String
    attribute :price, Float

    command "CreateProduct" do
      attribute :name, String
      attribute :price, Float
    end
  end
end

app = Hecks.load(domain)

# Create a separate read-side adapter
read_adapter = CatalogDomain::Adapters::ProductMemoryRepository.new
app.enable_cqrs("Product", read_repo: read_adapter)

# Commands write to the write repo
Product.create(name: "Widget", price: 9.99)

# Queries read from the read store (auto-synced via events)
Product.all          # reads from read store
Product.find(id)     # reads from read store
Product.where(name: "Widget")  # reads from read store
```

## Extension Activation

The `hecks_cqrs` extension auto-wires all aggregates when loaded:

```ruby
app = Hecks.load(domain)
app.extend(:cqrs)
```

This creates a ReadModelStore for each aggregate and subscribes to
all domain events for automatic synchronization.

## ReadModelStore API

```ruby
require "hecks/ports/read_model_store"

adapter = CatalogDomain::Adapters::ProductMemoryRepository.new
store = Hecks::ReadModelStore.new(adapter: adapter)

store.update(product)    # sync an aggregate into the read store
store.read               # returns the underlying adapter
store.read.all           # all records in the read store
store.find(id)           # find by ID
store.count              # record count
store.clear              # wipe all data
```

## Inspecting CQRS Status

```ruby
app.cqrs?                 # => true if any aggregate has CQRS
app.cqrs?("Product")      # => true if Product has CQRS
app.read_store_for("Product")  # => the ReadModelStore instance
```

## How Auto-Sync Works

When `enable_cqrs` or the CQRS extension is activated, the runtime
subscribes to every aggregate event. On each event, the write repo
is read and the read store is updated. This ensures eventual consistency
between write and read sides.

## Backward Compatibility

When no read store is registered for an aggregate, all operations use
the single repository adapter. No changes are needed for existing code.

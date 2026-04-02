# Event Versioning & Upcasting

Domain events evolve over time. When an event's schema changes (fields added, renamed, or removed), old stored events need to be transformed to match the current schema. Hecks provides a built-in upcasting system for this.

## Schema Version on Events

Declare the current schema version on explicit events:

```ruby
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    attribute :description, String

    event "CreatedPizza" do
      schema_version 2
      attribute :name, String
      attribute :description, String
    end

    command "CreatePizza" do
      attribute :name, String
      attribute :description, String
    end
  end
end
```

Events default to `schema_version 1` when not declared.

## Upcast Declarations

Declare transforms at the domain level that convert stored event data from one version to the next:

```ruby
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    attribute :description, String

    event "CreatedPizza" do
      schema_version 3
      attribute :name, String
      attribute :description, String
      attribute :category, String
    end

    command "CreatePizza" do
      attribute :name, String
      attribute :description, String
      attribute :category, String
    end
  end

  # v1 had "style" instead of "description"
  upcast "CreatedPizza", from: 1, to: 2 do |data|
    data.merge("description" => data.delete("style") || "")
  end

  # v2 didn't have "category"
  upcast "CreatedPizza", from: 2, to: 3 do |data|
    data.merge("category" => "classic")
  end
end
```

Upcasters chain automatically: a v1 event gets transformed through v1->v2 then v2->v3.

## Event Store Integration

When using the SQL EventRecorder, pass an upcaster engine to enable transparent upcasting on reads:

```ruby
domain = Hecks.domain "Pizzas" do
  # ... domain definition with upcast declarations ...
end

engine = Hecks::Events::BuildEngine.call(domain)
recorder = Hecks::Persistence::EventRecorder.new(db,
  upcaster_engine: engine,
  domain: domain
)

# Old v1 events are automatically upcasted when reading:
recorder.history("Pizza", "1")
# => [{ event_type: "CreatedPizza", data: { "name" => "...", "description" => "...", "category" => "classic" }, schema_version: 3 }]
```

New events are stored with the current schema version. Old events are upcasted on read -- the stored data is never modified.

## Standalone Usage

You can also use the upcasting components directly:

```ruby
registry = Hecks::Events::UpcasterRegistry.new
registry.register("CreatedPizza", from: 1, to: 2) do |data|
  data.merge("description" => data.delete("style") || "")
end

engine = Hecks::Events::UpcasterEngine.new(registry)
result = engine.upcast("CreatedPizza",
  data: { "name" => "M", "style" => "Napoli" },
  from_version: 1, to_version: 2
)
# => { "name" => "M", "description" => "Napoli" }
```

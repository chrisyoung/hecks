# CRUD Extension

Auto-generate Create, Update, and Delete commands for aggregates that
don't already define them. Useful for rapid prototyping or when every
aggregate needs standard CRUD operations.

## Enabling

```ruby
require "hecks/extensions/crud"
```

`hecks_on_rails` auto-includes this extension by default.

## Usage with Hecks.load (test/script path)

Enrich the domain IR before loading:

```ruby
domain = Hecks.domain "Pets" do
  aggregate "Cat" do
    attribute :name, String
    attribute :color, String
  end
end

Hecks::Crud::CommandGenerator.enrich(domain)
app = Hecks.load(domain)

cat = Cat.create(name: "Whiskers", color: "orange")
Cat.update(cat: cat.id, name: "Mittens")   # merges, keeps color
Cat.delete(cat: cat.id)                     # removes from repo
```

## Usage with existing commands (post-load path)

When aggregates already have some commands, the extension adds only
what's missing:

```ruby
domain = Hecks.domain "Widgets" do
  aggregate "Widget" do
    attribute :label, String

    command "CreateWidget" do
      attribute :label, String
    end
  end
end

app = Hecks.load(domain)
Hecks::Crud::CommandGenerator.generate_all(WidgetsDomain, domain, app)

# CreateWidget is unchanged, UpdateWidget and DeleteWidget are added
Widget.update(widget: w.id, label: "New Label")
Widget.delete(widget: w.id)
```

## Generated commands

For an aggregate `Pizza` with attributes `name` and `description`:

| Command | Shortcut | Behavior |
|---------|----------|----------|
| `CreatePizza` | `Pizza.create(name:, description:)` | Builds and persists a new aggregate |
| `UpdatePizza` | `Pizza.update(pizza:, name:, description:)` | Merges non-nil attrs with existing |
| `DeletePizza` | `Pizza.delete(pizza:)` | Removes from repository |

Each command emits a corresponding event: `CreatedPizza`, `UpdatedPizza`,
`DeletedPizza`.

## Idempotency

If an aggregate already defines `CreatePizza`, the extension skips it
and only generates `UpdatePizza` and `DeletePizza`. Running `generate_all`
or `enrich` multiple times is safe.

## Rails integration

When using `hecks_on_rails`, the CRUD extension is auto-required in the
Railtie initializer. All aggregates get CRUD commands unless they already
define them.

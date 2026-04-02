# Bubble Context (Anti-Corruption Layer)

The bubble context extension provides an anti-corruption layer (ACL) that
shields your domain from legacy or external system naming conventions.

## Setup

```ruby
require "hecks/extensions/bubble"

context = HecksBubble::Context.new
```

## Declaring Mappings

Use `map_aggregate` with `from_legacy` to declare field translations:

```ruby
context.map_aggregate :Pizza do
  from_legacy :pie_name, to: :name
  from_legacy :pie_desc, to: :description, transform: ->(v) { v.to_s.strip }
end
```

## Forward Translation (Legacy to Domain)

```ruby
legacy_data = { pie_name: "Margherita", pie_desc: "  Classic  " }
clean = context.translate(:Pizza, :create, legacy_data)
# => { name: "Margherita", description: "Classic" }
```

The second argument (`:create`) is the command verb -- informational for
logging. The actual mapping is aggregate-level.

## Reverse Translation (Domain to Legacy)

```ruby
domain_data = { name: "Margherita", description: "Classic" }
legacy = context.reverse(:Pizza, domain_data)
# => { pie_name: "Margherita", pie_desc: "Classic" }
```

Transforms are **not** applied in reverse (they may be lossy).

## Unmapped Fields

Fields not in the mapping pass through unchanged in both directions.
Unmapped aggregates return data as-is.

## Inspecting Mappings

```ruby
context.mapped_aggregates  # => [:Pizza]
```

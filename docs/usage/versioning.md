# Domain Interface Versioning

Tag, log, and diff domain interface versions to track breaking changes
across releases.

## Tag a version

Snapshot the current domain DSL as a named version:

```bash
hecks version_tag 1.0.0
# Tagged Banking as v1.0.0
#   Snapshot: db/hecks_versions/1.0.0.rb
```

The snapshot file contains a metadata header followed by the full DSL:

```ruby
# Hecks domain snapshot
# version: 1.0.0
# tagged_at: 2026-04-01
Hecks.domain "Banking" do
  aggregate "Account" do
    attribute :name, String
    command "CreateAccount" do
      attribute :name, String
    end
  end
end
```

## List versions

```bash
hecks version_log
# 2.1.0  2026-04-01  +FreezeAccount command, +tags attribute
# 1.0.0  2026-02-01  Initial snapshot
```

## Diff versions

Diff two tagged versions:

```bash
hecks diff --v1 1.0.0 --v2 2.1.0
# 3 changes (v1.0.0 -> v2.1.0):
#
#   + command: Account.FreezeAccount
#   - command: Account.CloseAccount  <- BREAKING
#   + attribute: Account.tags (String)
#
# 1 breaking change!
```

Diff a tagged version against the working domain file:

```bash
hecks diff --v1 1.0.0
# 2 changes (v1.0.0 -> working):
#   ...
```

Diff working domain against the latest tagged version:

```bash
hecks diff
# No changes detected (v2.1.0 -> working).
```

## Breaking change rules

A change is **BREAKING** if:
- A command is removed or renamed
- A required attribute is removed
- An aggregate is removed

A change is **non-breaking** if:
- A command is added
- An attribute is added
- A query, scope, or specification is added

## Pin a consumer to a version

Lock a downstream consumer to a specific tagged version:

```bash
hecks version_pin billing-service --version 1.0.0
# Pinned billing-service to v1.0.0
```

Pins are stored in `db/hecks_versions/.pins.yml`:

```yaml
---
billing-service: "1.0.0"
frontend-app: "2.1.0"
```

## List all pins

```bash
hecks version_pins
# billing-service  v1.0.0
# frontend-app     v2.1.0
```

## Programmatic API

```ruby
# Pin a consumer
Hecks::DomainVersioning.pin("billing-service", "1.0.0", base_dir: Dir.pwd)

# Look up a pin
Hecks::DomainVersioning.pinned_version("billing-service", base_dir: Dir.pwd)
# => "1.0.0"

# List all pins
Hecks::DomainVersioning.all_pins(base_dir: Dir.pwd)
# => { "billing-service" => "1.0.0", "frontend-app" => "2.1.0" }
```

## Version round-trip in snapshots

When a domain declares `version:`, the serializer preserves it in snapshot files:

```ruby
Hecks.domain "Banking", version: "2.1.0" do
  # ...
end
```

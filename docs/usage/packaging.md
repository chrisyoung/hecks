# Packaging

Hecks features ship as separate packages so you only install what you use.

## What's Available

| Package | What It Adds |
|---|---|
| `hecks` | Core: DSL, code generation, runtime, event bus, memory adapters |
| `active_hecks` | Rails: validations, forms, callbacks, railtie, generators |
| `hecks_live` | Real-time: domain events stream to browsers via Turbo Streams |
| `hecks_on_rails` | Bundles `active_hecks` + `hecks_live` |
| `hecks_sqlite` | Persistence: SQLite via Sequel |

## For Rails Apps

```ruby
gem "hecks_on_rails"
```

This is the default. Brings everything: ActiveModel compat, real-time events, generators.

## For Plain Ruby

```ruby
gem "hecks"
```

Core only. Add persistence with `gem "hecks_sqlite"`.

## How They Compose

```
hecks_on_rails
├── active_hecks
│   └── hecks
└── hecks_live
    └── hecks
```

Extension packages auto-wire when present — no configuration needed.

# What the Hecks?!

Describe your business in Ruby. Hecks generates the code.

- [The Seam](#the-seam) — the core architecture
- [Quick Start](#quick-start) — zero to running domain
- [The DSL](#the-dsl) — define your business
- [Play Mode](#play-mode) — explore with live objects
- [One-Line SQL](#one-line-sql)
- [Banking Example](#banking-example) — a complete working domain

More: [Specifications](docs/content/specifications.md) · [Policies](docs/usage/policy_conditions.md) · [Domain-Level Policies](docs/usage/domain_level_policies.md) · [Error Messages](docs/usage/error_messages.md) · [Build-Time Checks](#build-time-checks) · [CLI Commands](#cli-commands) · [All Features](FEATURES.md)

## The Seam

{{content:seam}}

## Quick Start

```
$ hecks new banking
$ cd banking
$ ruby app.rb
```

That's it. One command scaffolds the project. `Hecks.boot(__dir__)` does the rest.

## The DSL

{{content:dsl}}

## Play Mode

```ruby
session = Hecks.session("Demo")
session.aggregate("Cat") do
  attribute :name, String
  command("Adopt") { attribute :name, String }
end

session.play!

whiskers = Cat.adopt(name: "Whiskers")
Cat.adopt(name: "Mittens")

Cat.count              # => 2
Cat.find(whiskers.id)  # => #<Cat name="Whiskers">

whiskers.name = "Sir Whiskers"
whiskers.reset!        # back to "Whiskers"
```

Sketch a domain, play with live objects, persist to memory. Same API as production.

## One-Line SQL

```ruby
app = Hecks.boot(__dir__, adapter: :sqlite)
```

One line. Tables created, adapters wired, data persisted to SQL. Works with SQLite, PostgreSQL, MySQL.

## Banking Example

{{content:banking_example}}

## Build-Time Checks

{{validation_rules}}

Every error includes a fix suggestion. [See examples.](docs/usage/error_messages.md)

## CLI Commands

{{cli_commands}}

## License

MIT

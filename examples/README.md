# Hecks Examples

## pizzas/

A standalone Hecks domain with three runnable scripts demonstrating different framework features:

- **`app.rb`** — Full workflow: build gem, wire Application container, use `Pizza.create` / `Pizza.find` / `pizza.toppings.create` API, subscribe to events
- **`repl_session.rb`** — Interactive domain building with the Session API, `session.apply!`, CalVer versioning, then play mode for command execution
- **`sql_app.rb`** — SQL schema and adapter generation with a live SQLite demo

```bash
ruby -Ilib examples/pizzas/app.rb
ruby -Ilib examples/pizzas/repl_session.rb
ruby -Ilib examples/pizzas/sql_app.rb
```

## rails_app/

Shows how to use a Hecks domain gem inside Rails. Includes `session.apply!` for writing domain objects to `app/models/`, `rails generate hecks:init` for setup, migration generation via `DomainDiff` and `SqlStrategy`, and collection proxies for value object lists.

See `rails_app/README.md` for setup instructions.

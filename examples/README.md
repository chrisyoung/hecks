# Hecks Examples

## pizzas/

A standalone Hecks domain with three runnable scripts demonstrating different framework features:

- **`app.rb`** — Full workflow: build gem, wire Application container, use `Pizza.create` / `Pizza.find` / `pizza.toppings.create` API, subscribe to events
- **`repl_session.rb`** — Interactive domain building with the Session API, CalVer versioning, then play mode for command execution
- **`sql_app.rb`** — SQL schema and adapter generation with a live SQLite demo

```bash
ruby -Ilib examples/pizzas/app.rb
ruby -Ilib examples/pizzas/repl_session.rb
ruby -Ilib examples/pizzas/sql_app.rb
```

## rails_app/

Shows how to use a Hecks domain gem inside Rails. Uses `Hecks.configure` for setup, `rails generate active_hecks:init` to scaffold the initializer, and `require "hecks/test_helper"` for automatic test cleanup. Domain objects come from the gem only -- no model files in the Rails app.

See `rails_app/README.md` for setup instructions.

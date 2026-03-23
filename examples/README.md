# Hecks Examples

## pizzas/

A standalone Hecks domain with three runnable scripts demonstrating different framework features:

- **`app.rb`** — Full workflow: build gem, wire Application, use commands, collection proxies, DSL query objects (`Pizza.by_description`), subscribe to events
- **`repl_session.rb`** — Interactive domain building with the Session API, CalVer versioning, then play mode for command execution
- **`sql_app.rb`** — SQL schema and adapter generation with a live SQLite demo

```bash
ruby -Ilib examples/pizzas/app.rb
ruby -Ilib examples/pizzas/repl_session.rb
ruby -Ilib examples/pizzas/sql_app.rb
```

## rails_app/

Shows how to use a Hecks domain gem inside Rails. Uses `Hecks.configure` with database config and `include_ad_hoc_queries` for the full ActiveRecord-style API. Controllers use DSL query objects (`Pizza.by_description`, `Order.pending`). Domain objects come from the gem — no model files in the Rails app.

See `rails_app/README.md` for setup instructions.

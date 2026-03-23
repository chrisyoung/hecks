# CLAUDE.md

## Before every commit

1. **Update docs** — sync all file doc headers and READMEs with current features
2. **Run specs** — `bundle exec rspec --order defined` (430+ specs, all must pass)
3. **Check file sizes** — no file over 200 lines (`find lib -name "*.rb" -exec wc -l {} + | sort -rn | head -5`)
4. **Smoke test** — `ruby -Ilib examples/pizzas/app.rb`
5. **Stage specifically** — don't `git add -A`, stage specific files to avoid Rails boilerplate leaking in
6. **Update .gitignore** if new generated/temp files appear

## .gitignore reminders

The `examples/rails_app/` has Rails-generated files that should NOT be committed:
- `bin/`, `public/`, `vendor/`, `lib/tasks/`, `.github/`, `.rubocop.yml`, `.ruby-version`
- `db/schema.rb`, `db/seeds.rb`, `log/`, `tmp/`, `storage/`
- Only commit: `app/`, `config/`, `db/migrate/`, `Gemfile`, `Rakefile`, `config.ru`, `README.md`

## Issue tracking

- Always use Linear for tracking work — create issues before starting, update status as you go
- Use the Linear MCP tools (list_issues, save_issue, etc.) to manage issues
- Tag issues with appropriate labels (e.g. "Repository")
- Mark issues Done when the work is committed and pushed

## Project conventions

- Every lib file has a doc comment header: class name, one-line purpose, architecture context, usage example
- No file over 200 lines — extract modules/classes if approaching the limit
- Tests run against memory adapters — fast and isolated
- CalVer versioning (YYYY.MM.DD.N) — no manual bumping
- `Hecks.configure` for Rails, `Application.new` for plain Ruby
- Aggregates are pure domain objects — no persistence logic mixed in
- Examples should use Hecks APIs (`Hecks.build`, `Hecks.configure`, `hecks serve`) — don't call generators or create tables manually

## Module grouping pattern

Group related files under a parent module with a `.bind` class method. The parent module file documents what's inside and delegates binding. Each child is a separate file with its own doc header.

```
services/
  persistence.rb          # parent: autoloads + Persistence.bind(klass, agg, repo)
  persistence/
    repository_methods.rb # RepositoryMethods.bind(klass, repo)
    collection_methods.rb
    collection_proxy.rb
    reference_methods.rb
```

Current module groups:
- `Services::Persistence` — RepositoryMethods, CollectionProxy, References
- `Services::Querying` — QueryBuilder, AdHocQueries, Scopes, Operators
- `Services::Commands` — CommandBus, CommandMethods, CommandRunner
- `Generators::Domain` — Aggregate, VO, Command, Event, Policy, Query
- `Generators::SQL` — SqlAdapter, SqlBuilder, SqlMigration
- `Generators::Infrastructure` — Port, MemoryAdapter, Autoload, Spec, DomainGem
- `DomainModel::Behavior` — Command, DomainEvent, Policy, Query
- `DomainModel::Structure` — Domain, Aggregate, ValueObject, Attribute, etc.
- `ValidationRules::Naming` / `References` / `Structure`
- `Session` — AggregateHandle, ContextHandle, Playground, ConsoleRunner
- `Migrations` — DomainDiff, DomainSnapshot, MigrationStrategy, MigrationRunner
- `HTTP` — DomainServer (REST+SSE), RpcServer (JSON-RPC), RouteBuilder
- `MCP` — DomainServer, SessionTools, AggregateTools, InspectTools, BuildTools, PlayTools

## CLI structure

Each CLI command is its own file under `lib/hecks/cli/commands/`. The CLI shell
(`cli.rb`) has shared helpers only. Add new commands by creating a new file.

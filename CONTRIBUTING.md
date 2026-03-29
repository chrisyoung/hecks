# Contributing to Hecks

Thanks for your interest in contributing! Here's how to get started.

## Setup

```bash
git clone https://github.com/chrisyoung/hecks.git
cd hecks
bundle install
bundle exec rspec
```

All 900+ specs should pass in under 1.5 seconds.

## Rules

- **No file over 200 lines of code** -- doc comment headers don't count toward this limit. Extract modules/classes by concern when approaching it.
- **Tests must run under 1 second** -- enforced by the pre-commit hook. Adjust with `SPEC_SPEED_LIMIT=2`.
- **Every lib file has a doc comment header** -- class name, purpose, usage example.
- **Memory adapters for tests** -- fast and isolated. No database setup required.

## Workflow

1. Fork the repo and create a branch from `main`
2. Write your code and specs
3. Run `bundle exec rspec` -- all must pass
4. Run `ruby -Ilib examples/pizzas/app.rb` as a smoke test
5. Check file sizes: `find lib -name "*.rb" -exec wc -l {} + | sort -rn | head -5`
6. Update FEATURES.md if you added a new feature
7. Add `docs/usage/<feature>.md` with runnable examples for new features
8. Do your changes require cli updates?
9. Open a pull request

## Architecture

Hecks is a monorepo with multiple gem components:

| Component | Purpose |
|---|---|
| `hecksties` | Core kernel: DSL, autoloads, version |
| `hecks_model` | Domain model types and DSL builders |
| `hecks_domain` | Compiler, generators, inspectors |
| `hecks_runtime` | Orchestration, ports, extensions |
| `hecks_workbench` | Workbench (interactive domain modeling), MCP server, AI tools |
| `hecks_cli` | Thor CLI and HTTP server |
| `hecks_persist` | SQL persistence via Sequel |
| `hecks_watchers` | File watchers for development |

Cross-component loading must use bare `require`, not `require_relative`. The pre-commit hook enforces this.

## Conventions

- CalVer versioning (YYYY.MM.DD.N)
- Aggregates are pure domain objects -- no persistence logic
- CLI commands go in `hecks_cli/lib/hecks_cli/commands/`, one file per command
- Generators show a diff when a target file already exists (never silently overwrite)

## Reporting Issues

Use [GitHub Issues](https://github.com/chrisyoung/hecks/issues). Include:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Ruby version and OS

# Hecks Extensions

All extensions use the unified `extend` API:

```ruby
app = Hecks.boot(__dir__) do
  extend :sqlite
  extend :tenancy
  extend :slack, webhook: ENV["SLACK_URL"]
end
```

## Persistence

| Extension | Usage | Description |
|-----------|-------|-------------|
| **sqlite** | `extend :sqlite` | SQLite persistence via Sequel. [README](hecks_persist/README.md) |
| **postgres** | `extend :postgres` | PostgreSQL persistence via Sequel. [README](hecks_persist/README.md) |
| **mysql** | `extend :mysql` | MySQL persistence via Sequel. [README](hecks_persist/README.md) |
| **cqrs** | `extend :sqlite, as: :write` | Named read/write connections for CQRS. [Source](hecks_persist/lib/hecks/extensions/cqrs.rb) |
| **transactions** | `extend :transactions` | DB transaction wrapping for SQL adapters. [Source](hecks_persist/lib/hecks/extensions/transactions.rb) |
| **filesystem_store** | `extend :filesystem_store` | JSON file persistence for development. [Source](hecks_runtime/lib/hecks/extensions/filesystem_store.rb) |

## Application Services

| Extension | Usage | Description |
|-----------|-------|-------------|
| **validations** | auto | Field-level validation enforcement (presence, format, length). [Source](hecks_runtime/lib/hecks/extensions/validations.rb) |
| **auth** | `extend :auth` | Actor-based authorization via port definitions. [Source](hecks_runtime/lib/hecks/extensions/auth.rb) |
| **tenancy** | `extend :tenancy` | Multi-tenant data isolation. [Source](hecks_runtime/lib/hecks/extensions/tenancy.rb) |
| **audit** | `extend :audit` | Audit trail logging for every command execution. [Source](hecks_runtime/lib/hecks/extensions/audit.rb) |
| **pii** | `extend :pii` | Encryption and masking for personally identifiable information. [Source](hecks_runtime/lib/hecks/extensions/pii.rb) |
| **idempotency** | `extend :idempotency` | Deduplicates identical command dispatches. [Source](hecks_runtime/lib/hecks/extensions/idempotency.rb) |
| **logging** | `extend :logging` | Command execution timing and logging. [Source](hecks_runtime/lib/hecks/extensions/logging.rb) |
| **rate_limit** | `extend :rate_limit` | Per-command rate limiting. [Source](hecks_runtime/lib/hecks/extensions/rate_limit.rb) |
| **retry** | `extend :retry` | Exponential backoff for transient errors. [Source](hecks_runtime/lib/hecks/extensions/retry.rb) |

## Infrastructure

| Extension | Usage | Description |
|-----------|-------|-------------|
| **web_explorer** | `extend :http` | Interactive web UI with forms, lifecycle badges, event logs. [Source](hecks_runtime/lib/hecks/extensions/web_explorer.rb) |
| **serve** | `hecks serve` | WEBrick HTTP server for generated static apps. [README](hecks_cli/README.md) |
| **mcp** | `hecks mcp` | MCP server for AI-driven domain modeling. [Source](hecks_workshop/lib/hecks/extensions/ai.rb) |

## Cross-Domain

| Extension | Usage | Description |
|-----------|-------|-------------|
| **listen** | `extend CommentsDomain` | Subscribe to another domain's event bus. |
| **outbound** | `extend :slack, webhook: url` | Forward events to external systems. |

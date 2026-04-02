# Redis Store (Experimental)

Redis-backed persistence extension. Stores aggregates as JSON strings
using GET/SET/DEL/SCAN operations.

**Stability: experimental** -- API may change in future releases.

## Setup

```ruby
require "redis"

app = Hecks.boot(__dir__)
app.extend(:redis_store, client: Redis.new(url: "redis://localhost:6379"))
```

## How It Works

Each aggregate is stored at `hecks:<domain>:<aggregate>:<id>` as a
JSON-serialized hash. The repository implements the full Hecks interface:

| Method | Redis Operation |
|--------|----------------|
| `find(id)` | `GET` |
| `save(agg)` | `SET` |
| `delete(id)` | `DEL` |
| `all` | `SCAN` + `GET` |
| `count` | `SCAN` |
| `clear` | `SCAN` + `DEL` |
| `query(conditions:)` | `SCAN` + in-memory filter |

## Testing

Use a mock Redis client in tests:

```ruby
class MockRedis
  def initialize; @store = {}; end
  def get(key); @store[key]; end
  def set(key, value); @store[key] = value; end
  def del(key); @store.delete(key); end
  def scan(cursor, match:, count: 100)
    pattern = Regexp.new(Regexp.escape(match).gsub("\\*", ".*"))
    ["0", @store.keys.select { |k| k.match?(pattern) }]
  end
end

app.extend(:redis_store, client: MockRedis.new)
```

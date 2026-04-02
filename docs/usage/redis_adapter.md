# Redis Adapter

**Status: Experimental** -- API may change.

Persist domain aggregates in Redis as JSON strings. Each aggregate is stored
under a namespaced key: `hecks:<domain>:<aggregate>:<id>`.

## Setup

Add the `redis` gem to your Gemfile:

```ruby
gem "redis"
```

### Auto-wire via boot

```ruby
app = Hecks.boot(__dir__, adapter: :redis)
```

### Environment

Set `REDIS_URL` to point at your Redis instance (default: `redis://localhost:6379`):

```bash
REDIS_URL=redis://localhost:6379/1 ruby app.rb
```

## Key namespace

Keys follow the pattern:

```
hecks:<domain>:<aggregate>:<id>
```

For a `Pizzas` domain with a `Pizza` aggregate and ID `abc-123`:

```
hecks:pizzas:pizza:abc-123
```

## Repository interface

The `RedisRepository` implements the standard Hecks repository methods:

| Method   | Redis operation        |
|----------|------------------------|
| `find`   | `GET` key              |
| `save`   | `SET` key with JSON    |
| `delete` | `DEL` key              |
| `all`    | `SCAN` + `MGET`        |
| `count`  | `SCAN` (count keys)    |
| `query`  | `SCAN` + filter/sort   |
| `clear`  | `SCAN` + `DEL`         |

## Direct usage (without boot)

```ruby
require "redis"
require "hecks/extensions/redis_store"

redis = Redis.new(url: "redis://localhost:6379")

repo = Hecks::RedisRepository.new(
  "Pizza",
  PizzasDomain::Pizza,
  redis: redis,
  namespace: "hecks:pizzas:pizza"
)

repo.save(pizza)
repo.find(pizza.id)
repo.all
repo.query(conditions: { name: "Margherita" }, order_key: :name, limit: 10)
repo.clear
```

## Notes

- All values are JSON-serialized strings. Redis is used as a document store.
- `all`, `count`, `query`, and `clear` use `SCAN` to enumerate keys, which is
  safe for large keyspaces but not transactional.
- Value objects and nested attributes are serialized as embedded JSON objects.
- Timestamps (`created_at`, `updated_at`) are stored as ISO 8601 strings.

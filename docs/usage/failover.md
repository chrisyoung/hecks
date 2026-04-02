# Failover Extension

Wraps repositories with a FailoverProxy that gracefully handles primary
adapter failures. Writes are queued in a log and reads fall back to an
in-memory store. Recovery replays the write log against the primary.

## Setup

```ruby
app = Hecks.boot(__dir__)
app.extend(:failover)
```

## Usage

```ruby
# Check status
Hecks.failover_status       # => :healthy or :degraded
Hecks.failover_queue_size   # => 0

# When the primary fails, operations continue against the fallback
Pizza.create(name: "Margherita")  # queued if primary is down

# When the primary recovers, replay the write log
Hecks.failover_recover!     # => 3 (number of replayed operations)
Hecks.failover_status       # => :healthy
```

## How It Works

1. Each repository is wrapped in a `FailoverProxy`
2. On write failure: the operation is saved to an in-memory write log
   and executed against a fallback hash store
3. On read failure: data is served from the fallback store
4. `recover!` replays all queued writes against the primary, then clears
   the log and fallback store

## API

| Method | Description |
|--------|-------------|
| `Hecks.failover_status` | `:healthy` or `:degraded` |
| `Hecks.failover_recover!` | Replay write log to primary |
| `Hecks.failover_queue_size` | Number of queued write operations |

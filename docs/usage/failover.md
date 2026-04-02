# Failover Extension

Automatic repository failover with write-log recovery. When a primary
repository (e.g. SQL, Mongo) becomes unavailable, the FailoverProxy
transparently switches to an in-memory fallback. All writes are logged
for replay when the primary recovers.

## Setup

```ruby
require "hecks/extensions/failover"

domain = Hecks.domain "Orders" do
  aggregate "Order" do
    attribute :total, Float
    command "PlaceOrder" do
      attribute :total, Float
    end
  end
end

app = Hecks.load(domain)
# Extension auto-wires -- all repos are now wrapped with FailoverProxy
```

## Checking status

```ruby
Hecks.failover_status
# => { mode: :primary, write_log_size: 0 }

# After a primary failure:
# => { mode: :failover, write_log_size: 3 }
```

## Manual recovery

```ruby
Hecks.failover_recover!
# => { recovered: 1, still_failed: 0 }
```

## Background recovery

```ruby
# Start a background thread that checks every 30 seconds
monitor = Hecks.instance_variable_get(:@_failover_monitor)
monitor.start(interval: 30)

# Stop background recovery
monitor.stop
```

## How it works

1. Each repository gets wrapped with `HecksFailover::FailoverProxy`
2. Reads and writes delegate to the primary repository
3. When the primary raises any `StandardError`, the proxy:
   - Switches to `:failover` mode
   - Copies existing primary data to in-memory fallback (best effort)
   - Routes all operations to the fallback
4. Writes during failover are recorded in `write_log`
5. `recover!` tests the primary, replays the write log, and switches back

## FailoverProxy API

```ruby
proxy = HecksFailover::FailoverProxy.new(sql_repo)

proxy.mode          # => :primary or :failover
proxy.failed_over?  # => true/false
proxy.write_log     # => [{ op: :save, args: [...], at: Time }]
proxy.recover!      # => true if recovery succeeded
```

## RecoveryMonitor API

```ruby
monitor = HecksFailover::RecoveryMonitor.new(proxies)

monitor.recover!               # => { recovered: N, still_failed: N }
monitor.start(interval: 30)    # background thread
monitor.stop                   # stop background thread
```

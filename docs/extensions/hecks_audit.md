# Audit Trail

Immutable event log with command context, actor, and tenant

## Install

```ruby
# Gemfile
gem "hecks_audit"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Auto-records every domain event.
# Pairs with hecks_auth for actor tracking.
```

## Details

Audit trail extension that records an immutable log entry for every
domain event published on the event bus. Captures the event class name,
full attribute data, and timestamp. Optionally pairs with command bus
middleware to enrich entries with command name, actor, and tenant.

Usage:
  require "hecks_audit"

  app = Hecks.load(domain)
  audit = HecksAudit.new(app.event_bus)

  # Optional: add command context via middleware
  app.use(:audit) { |cmd, nxt| audit.around_command(cmd, nxt) }

  Pizza.create(name: "Margherita")
  audit.log.last[:event_name]  # => "CreatedPizza"
  audit.log.last[:event_data]  # => { name: "Margherita" }

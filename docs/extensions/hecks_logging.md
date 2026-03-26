# Logging

Structured command logging — name, duration, actor, tenant

## Install

```ruby
# Gemfile
gem "hecks_logging"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Output:
# [hecks] CreatePizza 0.3ms actor=admin tenant=acme
```

## Details

Connection gem that provides structured logging of command dispatch to $stdout.
Shows command name, duration in milliseconds, actor, and tenant.
Registered as command bus middleware via Hecks.register_extension.

  require "hecks_logging"
  app = Hecks.load(domain)
  Pizza.create(name: "Margherita")
  # => [hecks] CreatePizza 0.3ms actor=admin tenant=acme

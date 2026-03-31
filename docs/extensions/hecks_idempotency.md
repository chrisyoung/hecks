# Idempotency

Command deduplication by fingerprinting within a TTL window

## Install

```ruby
# Gemfile
gem "hecks_idempotency"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Same command re-executed within TTL returns cached result.
# HECKS_IDEMPOTENCY_TTL=300
```

## Details

Idempotency connection for Hecks command bus. Deduplicates retried
commands by fingerprinting the command class and its attributes. If
the same fingerprint is seen within a TTL window, returns the cached
result instead of re-executing. Controlled via ENV:

  HECKS_IDEMPOTENCY_TTL — cache TTL in seconds (default: 300)

Usage:

  require "hecks_idempotency"
  app.run("CreatePizza", name: "Margherita")  # first call executes
  app.run("CreatePizza", name: "Margherita")  # second call returns cached

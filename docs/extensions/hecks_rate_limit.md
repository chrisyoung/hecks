# Rate Limiting

Sliding window rate limiting per actor

## Install

```ruby
# Gemfile
gem "hecks_rate_limit"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# HECKS_RATE_LIMIT=60  (max commands per window)
# HECKS_RATE_PERIOD=60 (window in seconds)
```

## Details

Rate limiting connection for Hecks command bus. Uses a sliding window
counter per actor to limit how many commands an actor can dispatch in
a configurable time period. Controlled via ENV vars:

  HECKS_RATE_LIMIT  — max commands per window (default: 60)
  HECKS_RATE_PERIOD — window size in seconds (default: 60)

Usage:

  require "hecks_rate_limit"
  Hecks.actor = current_user
  app.run("CreatePizza", name: "Margherita")  # rate-limited per actor

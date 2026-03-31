# Transactions

Wraps command execution in database transactions when SQL is present

## Install

```ruby
# Gemfile
gem "hecks_transactions"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Auto-detects Sequel repositories.
# Falls through for memory adapters.
```

## Details

Command bus middleware that wraps command execution in a database
transaction when a SQL adapter is present. Checks if the command's
repository responds to `db` (Sequel repositories do) and wraps in
`db.transaction { }`. Falls through transparently for memory adapters.

Future gem: hecks_transactions

  require "hecks_transactions"
  # Automatically registered — all commands through SQL repos
  # will execute inside a database transaction.

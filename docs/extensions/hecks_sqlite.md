# SQLite

SQLite persistence — zero-config, file-based SQL database

## Install

```ruby
# Gemfile
gem "hecks_sqlite"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Just add the gem. SQLite auto-wires on boot.
Cat.create(name: "Whiskers")
Cat.all  # persisted to SQLite
```

## Details

SQLite persistence connection for Hecks domains. Auto-wires when present
in the Gemfile — no configuration needed. Uses Sequel with sqlite3.

Future gem: hecks_sqlite

  # Gemfile
  gem "cats_domain"
  gem "hecks_sqlite"   # that's it — SQLite auto-wires

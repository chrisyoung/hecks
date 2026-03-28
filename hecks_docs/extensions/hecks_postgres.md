# PostgreSQL

PostgreSQL persistence — production-grade relational database

## Install

```ruby
# Gemfile
gem "hecks_postgres"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Set HECKS_DB_HOST, HECKS_DB_NAME, HECKS_DB_USER
CatsDomain.boot(adapter: { type: :postgres, host: "localhost", database: "cats" })
```

## Details

PostgreSQL persistence connection for Hecks domains. Auto-wires when
present in the Gemfile. Uses Sequel with the pg driver.

Future gem: hecks_postgres

  # Gemfile
  gem "cats_domain"
  gem "hecks_postgres"   # auto-wires Postgres

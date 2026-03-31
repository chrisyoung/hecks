# MySQL

MySQL persistence — widely deployed relational database

## Install

```ruby
# Gemfile
gem "hecks_mysql"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Set HECKS_DB_HOST, HECKS_DB_NAME, HECKS_DB_USER env vars
```

## Details

MySQL persistence connection for Hecks domains. Auto-wires when
present in the Gemfile. Uses Sequel with the mysql2 driver.

Future gem: hecks_mysql

  # Gemfile
  gem "cats_domain"
  gem "hecks_mysql"   # auto-wires MySQL

# Auth

Actor-based access control on commands

## Install

```ruby
# Gemfile
gem "hecks_auth"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# DSL: actor "Admin" on commands
Hecks.actor = current_user
# Middleware checks role automatically
```

## Details

Authentication and authorization connection for Hecks domains. Reads
actor metadata from the DSL and registers command bus middleware that
enforces access control. Commands without actors are always allowed.

Future gem: hecks_auth

  # Gemfile
  gem "cats_domain"
  gem "hecks_auth"

  # Set the current actor (any object responding to #role)
  Hecks.actor = OpenStruct.new(role: "Admin")
  Cat.adopt(name: "Whiskers")  # checks actor role against DSL

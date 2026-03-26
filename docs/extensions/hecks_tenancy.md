# Multi-tenancy

Tenant isolation — same domain, different data per tenant

## Install

```ruby
# Gemfile
gem "hecks_tenancy"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# DSL: tenancy :column
Hecks.tenant = "acme"
Cat.all  # only acme's cats
```

## Details

Multi-tenancy connection for Hecks domains. Wraps repositories with
tenant-scoped proxies so each tenant sees isolated data. Declare
the strategy in the DSL with `tenancy :column`.

Future gem: hecks_tenancy

  # Gemfile
  gem "cats_domain"
  gem "hecks_tenancy"

  # Console
  Hecks.tenant = "acme"
  Cat.create(name: "Whiskers")   # stored under acme

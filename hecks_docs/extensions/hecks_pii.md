# PII Protection

Mark attributes as PII — masking, redaction, and GDPR erasure

## Install

```ruby
# Gemfile
gem "hecks_pii"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# DSL: attribute :email, String, pii: true
CatsDomain.erase_pii(customer_id)
```

## Details

PII protection extension for Hecks domains. Reads `pii: true` markers
on attributes and provides masking, redaction, and erasure capabilities.

Future gem: hecks_pii

  # DSL
  attribute :email, String, pii: true

  # Gemfile
  gem "cats_domain"
  gem "hecks_pii"

  # Erasure
  CatsDomain.erase_pii(customer_id)

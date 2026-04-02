# Contract Testing

Verify that any repository adapter satisfies the Hecks repository
contract using shared RSpec examples. Works with memory, SQL, Redis,
or custom adapters.

## Setup

```ruby
require "hecks/contract_testing"
Hecks::ContractTesting.install!
```

## Usage

```ruby
RSpec.describe MySqlPizzaRepository do
  it_behaves_like "a Hecks repository",
    domain: my_domain,
    aggregate_name: "Pizza",
    create_attrs: { name: "Margherita" }
end
```

## What It Tests

The shared examples verify:

| Test | Description |
|------|-------------|
| saves and finds by id | `create` then `find(id)` returns the entity |
| returns all saved entities | `all` includes created entities |
| counts saved entities | `count` reflects stored entities |
| deletes by id | `delete(id)` then `find(id)` returns nil |
| clears all entities | `clear` then `count` returns 0 |
| supports query with conditions | `query(conditions: { key: value })` returns matches |

## Custom Adapters

Any adapter that implements the standard repository interface
(`find`, `save`, `delete`, `all`, `count`, `clear`, `query`) can use
these shared examples to prove contract compliance.

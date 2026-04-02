# Contract Testing

Verify that any repository adapter conforms to the Hecks repository interface.

## Quick Start

```ruby
require "hecks/contract_testing"

RSpec.describe "Pizza memory adapter" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  before { @app = Hecks.load(domain) }

  include_examples "hecks repository contract",
    adapter: -> { PizzasDomain::Adapters::PizzaMemoryRepository.new },
    factory: -> { PizzasDomain::Pizza.new(name: "Margherita") }
end
```

## What It Tests

The shared examples exercise the full repository interface:

| Method | Assertions |
|--------|-----------|
| `save` + `find` | Persists and retrieves by ID; overwrites on duplicate |
| `find` | Returns `nil` for unknown ID |
| `delete` | Removes entity; no-op for unknown ID |
| `all` | Returns all entities; empty array when empty |
| `count` | Returns count; 0 when empty |
| `query` | Filters by conditions; supports limit and offset |
| `clear` | Removes all entities |

## Auto-Generate Specs

Generate contract specs for every aggregate in a domain:

```ruby
domain = Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end

Hecks::ContractTesting.generate_specs(domain, output_dir: "spec/contracts")
# => ["spec/contracts/pizza_repository_contract_spec.rb"]
```

Each generated file is standalone and includes the full domain DSL block,
so it can run without your app's boot sequence.

## Testing a Custom Adapter

```ruby
require "hecks/contract_testing"

RSpec.describe MySqlAdapter do
  before(:all) { setup_test_database }
  after(:all) { teardown_test_database }

  include_examples "hecks repository contract",
    adapter: -> { MySqlAdapter.new(connection: test_conn, table: "pizzas") },
    factory: -> { PizzasDomain::Pizza.new(name: "Test") }
end
```

Any adapter that passes all shared examples is guaranteed to work with
the Hecks runtime.

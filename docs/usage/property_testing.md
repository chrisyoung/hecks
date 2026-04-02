# Property-Based Testing

Generate random valid inputs for domain types, aggregates, and commands. No external gems required.

## TypeGenerator

```ruby
require "hecks/property_testing"

gen = Hecks::PropertyTesting::TypeGenerator.new(seed: 42)
gen.string   # => "dxpk"    (reproducible with same seed)
gen.integer  # => 4821
gen.float_val # => 123.45
gen.boolean  # => true
gen.for_type(String)  # => "mwqr"
```

## AggregateGenerator

```ruby
domain = Hecks.domain("Pizzas") { ... }
agg = domain.aggregates.first

gen = Hecks::PropertyTesting::AggregateGenerator.new(agg, seed: 42)

# Generate attributes for a command
attrs = gen.command_attrs("CreatePizza")
# => { name: "dxpk", description: "mwqr" }

# Generate multiple samples
samples = gen.samples("CreatePizza", count: 100)
```

## DomainFuzzer

```ruby
domain = Hecks.domain("Pizzas") { ... }

fuzzer = Hecks::PropertyTesting::DomainFuzzer.new(domain, seed: 42, rounds: 100)
report = fuzzer.run

report[:successes]  # => 95
report[:failures]   # => [{ command: "PlaceOrder", error: "...", attrs: {...} }]
report[:seed]       # => 42 (reproduce failures with same seed)
```

## RSpec Integration

```ruby
require "hecks/property_testing"

RSpec.describe "Pizza domain" do
  let(:domain) { Hecks.boot(__dir__) }
  let(:fuzzer) { Hecks::PropertyTesting::DomainFuzzer.new(domain, seed: 42, rounds: 50) }

  it "handles random valid inputs without crashing" do
    report = fuzzer.run
    expect(report[:failures]).to be_empty
  end
end
```

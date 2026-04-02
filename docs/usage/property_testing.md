# Property-Based Testing

Generate random valid data from your domain IR and fuzz-test your aggregates.
No external gems required.

## Setup

```ruby
# spec_helper.rb or wherever you need it
require "hecks/test_helper/property_testing"
```

## Type Generators

Generate random values for any Hecks attribute type:

```ruby
gen = Hecks::TestHelper::PropertyTesting::TypeGenerators.new(seed: 42)

gen.generate(String)    # => "prop_kxqz"
gen.generate(Integer)   # => 847
gen.generate(Float)     # => 312.45
gen.generate(Date)      # => #<Date: 2026-06-15>
gen.generate(DateTime)  # => #<DateTime: 2026-06-15T10:30:00>
gen.generate(JSON)      # => { "beta" => 73 }
gen.generate("Pizza")   # => "a1b2c3d4-e5f6-..." (reference UUID)
```

Same seed produces the same sequence every time.

## Aggregate Generator

Generate N random attribute hashes from an aggregate's IR:

```ruby
domain = Hecks.domain("Pizzas") do
  aggregate "Pizza" do
    attribute :name, String
    attribute :style, String
    attribute :price, Float
  end
end

pizza_agg = domain.aggregates.first
gen = Hecks::TestHelper::PropertyTesting::AggregateGenerator.new(pizza_agg, seed: 42)

gen.generate(3)
# => [
#   { name: "prop_abc", style: "prop_def", price: 123.45 },
#   { name: "prop_ghi", style: "prop_jkl", price: 678.90 },
#   { name: "prop_mno", style: "prop_pqr", price: 234.56 }
# ]

# Generate for a specific command
gen.generate_for_command("CreatePizza", 5)
```

## Domain Fuzzer

Fuzz-test an entire domain by running random data through create commands:

```ruby
domain = Hecks.domain("Pizzas") { ... }
runtime = Hecks.load(domain)

fuzzer = Hecks::TestHelper::PropertyTesting::DomainFuzzer.new(domain, runtime, seed: 42)
report = fuzzer.run(iterations: 50)

report.passed?          # => true
report.summary          # => "100/100 passed across 2 aggregate(s)"
report.failures         # => [] (empty when all pass)
report.failure_details  # => ["Pizza#CreatePizza: TypeError -- ..."]
report.seed             # => 42 (for reproducing failures)
```

## RSpec Integration

### property_test helper

Run assertions against N random attribute hashes:

```ruby
RSpec.describe "Pizza properties" do
  include Hecks::TestHelper::PropertyTesting::RSpecHelpers

  let(:domain) { Hecks.domain("Pizzas") { ... } }
  let(:pizza_agg) { domain.aggregates.first }

  it "always generates string names" do
    property_test(pizza_agg, count: 100, seed: 42) do |attrs|
      expect(attrs[:name]).to be_a(String)
      expect(attrs[:name].length).to be > 0
    end
  end
end
```

### survive_fuzz_testing matcher

Assert that a domain survives N iterations of random input:

```ruby
RSpec.describe "Domain fuzz test" do
  let(:domain) { Hecks.domain("Pizzas") { ... } }
  let(:runtime) { Hecks.load(domain) }

  it "survives fuzz testing" do
    expect([domain, runtime]).to survive_fuzz_testing(iterations: 50, seed: 42)
  end
end
```

On failure, the matcher prints the seed and all failure details so you can
reproduce the exact sequence.

## Reproducibility

Every generator accepts a `seed:` parameter. When a test fails, note the seed
from the output and pass it back to reproduce the exact same random sequence:

```ruby
# Failure output: "Fuzz testing failed (seed: 12345):"
# Reproduce:
fuzzer = DomainFuzzer.new(domain, runtime, seed: 12345)
report = fuzzer.run(iterations: 50)
```

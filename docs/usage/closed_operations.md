# Closed Operations on Value Objects

Closure of operations is a DDD pattern where an operation on a value object
returns a new instance of the same type. Money plus Money gives Money.
Weight plus Weight gives Weight.

## DSL

```ruby
Hecks.domain "Finance" do
  aggregate "Account" do
    attribute :balance, Float

    value_object "Money" do
      attribute :amount, Integer
      attribute :currency, String

      operation(:+) do |other|
        { amount: amount + other.amount, currency: currency }
      end

      operation(:-) do |other|
        { amount: amount - other.amount, currency: currency }
      end
    end

    command "CreateAccount" do
      attribute :balance, Float
    end
  end
end
```

The block receives `other` (another instance of the same value object) and
returns a hash of keyword arguments for constructing a new instance.

## Generated Ruby

Each `operation` becomes a method on the generated value object class:

```ruby
class Money
  attr_reader :amount, :currency

  def initialize(amount:, currency:)
    @amount = amount
    @currency = currency
    check_invariants!
    freeze
  end

  # Closed operations -- return same type
  def +(other)
    self.class.new(instance_exec(other, &proc { |other| { amount: amount + other.amount, currency: currency } }))
  end

  def -(other)
    self.class.new(instance_exec(other, &proc { |other| { amount: amount - other.amount, currency: currency } }))
  end

  # ... equality, hash, invariants ...
end
```

## Usage at Runtime

```ruby
ten = FinanceDomain::Account::Money.new(amount: 10, currency: "USD")
five = FinanceDomain::Account::Money.new(amount: 5, currency: "USD")

fifteen = ten + five
fifteen.amount    # => 15
fifteen.currency  # => "USD"
fifteen.frozen?   # => true

diff = ten - five
diff.amount       # => 5
```

## Named Operations

Operators are not required. Any name works:

```ruby
value_object "Weight" do
  attribute :grams, Integer

  operation(:combine) do |other|
    { grams: grams + other.grams }
  end
end
```

```ruby
box = ShippingDomain::Package::Weight.new(grams: 500)
label = ShippingDomain::Package::Weight.new(grams: 50)
total = box.combine(label)
total.grams  # => 550
```

## Serializer Round-Trip

Operations are preserved when serializing to DSL and back:

```ruby
domain = Hecks.domain("Finance") { ... }
source = Hecks::DslSerializer.new(domain).serialize
restored = eval(source)
restored.aggregates.first.value_objects.first.operations.size  # same as original
```

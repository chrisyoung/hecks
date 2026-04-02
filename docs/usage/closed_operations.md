# Closed Operations on Value Objects

Value objects can define **closed operations** -- methods that take another
instance of the same type and return a new instance of that type. This
follows the DDD principle of "closure of operations."

## DSL

```ruby
Hecks.domain "Finance" do
  aggregate "Account" do
    attribute :name, String

    value_object "Money" do
      attribute :amount, Integer
      attribute :currency, String

      operation :add, operator: :+ do |other|
        self.class.new(amount: amount + other.amount, currency: currency)
      end

      operation :subtract, operator: :- do |other|
        self.class.new(amount: amount - other.amount, currency: currency)
      end
    end

    command "CreateAccount" do
      attribute :name, String
    end
  end
end
```

## Usage

```ruby
app = Hecks.boot(__dir__)

a = FinanceDomain::Account::Money.new(amount: 100, currency: "USD")
b = FinanceDomain::Account::Money.new(amount: 25, currency: "USD")

# Named method
result = a.add(b)
result.amount    # => 125
result.currency  # => "USD"

# Operator alias
result = a + b
result.amount    # => 125

# Subtract (named only, no operator alias)
diff = a.subtract(b)
diff.amount      # => 75
```

## Key Points

- Operations are defined with `operation :name do |other| ... end`
- Optional `operator:` creates a Ruby operator alias (e.g., `+`, `-`, `*`)
- The block receives `other` (same type) and must return a new instance
- Results are frozen, just like all value objects
- Serialized in DSL round-trips via `DslSerializer`

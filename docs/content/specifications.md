Specifications are reusable business predicates defined in the DSL. Each becomes a class with a `satisfied_by?` method.

```ruby
aggregate "Loan" do
  specification "HighRisk" do |loan|
    loan.principal > 50_000 && loan.rate > 10
  end
end

aggregate "Account" do
  specification "LargeWithdrawal" do |withdrawal|
    withdrawal.amount > 10_000
  end
end
```

Use them at runtime:

```ruby
high_risk = Loan::Specifications::HighRisk.new
high_risk.satisfied_by?(loan)  # => true or false
```

Compose specifications with `and`, `or`, and `not`:

```ruby
high_risk = Loan::Specifications::HighRisk.new
large     = Account::Specifications::LargeWithdrawal.new

# Combine with logical operators
risky_and_large = high_risk.and(large)
risky_or_large  = high_risk.or(large)
not_risky       = high_risk.not
```

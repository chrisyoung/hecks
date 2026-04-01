# Specifications

Specifications are reusable, composable predicate objects that encode business
rules. They follow the DDD Specification pattern and support boolean composition
with AND, OR, and NOT operators.

## DSL

Define specifications inside an aggregate block. Two forms are supported:

### Declarative form (description only)

Use when you want to declare the business rule's intent. The predicate body
is implemented in the generated class.

```ruby
Hecks.domain "Orders" do
  aggregate "Order" do
    attribute :total, Integer
    attribute :status, String

    specification "HighValue" do
      description "Orders over $1000"
    end

    specification "Pending" do
      description "Orders awaiting fulfillment"
    end
  end
end
```

### Predicate form (executable block)

Use when the rule can be expressed inline. The block receives an aggregate
instance and returns true/false.

```ruby
Hecks.domain "Orders" do
  aggregate "Order" do
    attribute :total, Integer

    specification "HighValue" do |order|
      order.total > 1000
    end
  end
end
```

## Runtime usage

Generated specification classes include `Hecks::Specification`, which provides
`satisfied_by?` and boolean composition methods.

```ruby
# Instance-level
spec = Orders::Order::Specifications::HighValue.new
spec.satisfied_by?(order)  # => true/false

# Class-level shortcut
Orders::Order::Specifications::HighValue.satisfied_by?(order)
```

## Composition

Specifications can be combined using AND, OR, and NOT:

```ruby
high_value = Orders::Order::Specifications::HighValue.new
pending    = Orders::Order::Specifications::Pending.new

# AND -- both must be satisfied
combo = high_value.and(pending)
combo.satisfied_by?(order)  # => true only if both pass

# OR -- at least one must be satisfied
either = high_value.or(pending)
either.satisfied_by?(order)  # => true if either passes

# NOT -- negation
not_high = high_value.not
not_high.satisfied_by?(order)  # => true if order is NOT high value

# Chaining
complex = high_value.not.and(pending)
complex.satisfied_by?(order)  # => true if not high value AND pending
```

## Generated code

Running `hecks build` produces specification classes under
`Aggregate::Specifications`:

```ruby
module OrdersDomain
  class Order
    module Specifications
      # Orders over $1000
      class HighValue
        include OrdersDomain::Runtime::Specification

        def satisfied_by?(object)
          raise NotImplementedError, "HighValue#satisfied_by? must be implemented"
        end
      end
    end
  end
end
```

For predicate-form specifications, the `satisfied_by?` method body comes
directly from the DSL block.

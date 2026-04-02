# Naming Analysis

Hecks includes three naming analysis rules that produce non-blocking warnings
during validation. They help enforce intention-revealing, DDD-idiomatic names
throughout your domain model.

## Intention-Revealing Names

Warns when aggregate, value object, or entity names contain generic terms that
hide domain intent.

**Flagged terms:** Data, Info, Manager, Handler, Processor, Helper, Util, Utils,
Service, Object, Base, Item, Record, Entry, Wrapper, Container

```ruby
Hecks.domain "Orders" do
  aggregate "OrderManager" do          # warning: generic term 'Manager'
    attribute :name, String
    command("CreateOrderManager") { attribute :name, String }
  end
end
```

Fix: rename to a domain-specific concept like `Order`, `Fulfillment`, or
`Dispatcher`.

## Event Naming (Past Tense)

Warns when domain event names do not follow past-tense convention. Events
describe something that already happened.

```ruby
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command("CreatePizza") { attribute :name, String }
    event "BakePizza"                  # warning: not past tense
  end
end
```

Fix: rename to `BakedPizza`. The rule checks for common English past-tense
endings (`-ed`, `-en`, `-nt`, `-un`, `-id`).

## Attribute Naming

Warns on three attribute naming patterns:

### Vague suffixes

Suffixes like `_data`, `_info`, `_details` add no meaning:

```ruby
attribute :order_data, String          # warning: vague suffix '_data'
```

Fix: rename to `order` or a more specific term like `order_summary`.

### Redundant aggregate prefix

The aggregate name already provides context:

```ruby
aggregate "Pizza" do
  attribute :pizza_name, String        # warning: redundant prefix 'pizza_'
end
```

Fix: rename to `name`.

### Hungarian-style type prefix

Types are declared explicitly in the DSL:

```ruby
attribute :str_name, String            # warning: Hungarian prefix 'str_'
```

Fix: rename to `name`.

## Running the analysis

All three rules run automatically during `hecks validate` and `hecks build`.
Warnings appear in the CLI output but do not block compilation.

```sh
hecks validate
# Warnings:
#   Aggregate 'OrderManager' uses generic term 'Manager' -- prefer a domain-specific name
#   Event 'BakePizza' in Pizza does not appear to be past tense
#   Attribute 'pizza_name' on Pizza has redundant prefix 'pizza_'
```

# Naming Analysis

Validation rules that warn about naming anti-patterns in your domain model.

## IntentionRevealingNames

Warns when aggregate or attribute names are too generic.

```ruby
# This triggers a warning:
aggregate "DataItem" do
  attribute :info, String
  command("CreateDataItem") { attribute :info, String }
end

# Better:
aggregate "Invoice" do
  attribute :description, String
  command("CreateInvoice") { attribute :description, String }
end
```

Generic words detected: data, info, item, thing, record, object, entry, stuff, blob, payload, manager, handler, processor, helper, util.

## EventNaming

Warns when domain events are not in past tense.

```ruby
# Events should read as "something that happened":
# Good: CreatedPizza, OrderPlaced, PaymentProcessed
# Bad:  CreatePizza, PlaceOrder, ProcessPayment

# Hecks auto-infers past-tense events from commands,
# so this mainly catches manually-declared events.
```

## AttributeNaming

Warns about Hungarian notation, type suffixes, and boolean prefixes.

```ruby
# Bad:
attribute :str_name, String      # Hungarian notation
attribute :name_string, String   # redundant type suffix
attribute :is_active, Boolean    # boolean prefix

# Good:
attribute :name, String
attribute :active, Boolean
```

## Running

```bash
hecks validate
```

All naming analysis rules produce warnings (not errors) and include fix hints.

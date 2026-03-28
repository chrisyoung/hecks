# Error Messages That Teach

Every validation error includes a suggestion for how to fix it.

## Examples

```ruby
domain = Hecks.domain "Test" do
  aggregate "Pizza" do
    attribute :name, String
    # no commands — will fail validation
  end
end

valid, errors = Hecks.validate(domain)
errors.each { |e| puts e }
```

```
Pizza has no commands. Add a command: command "CreatePizza" do attribute :name, String end
```

## More examples

**Bad command name:**
```
Command Data in Pizza doesn't start with a verb. Try 'CreateData' or register
a custom verb with add_verb('Data') or verbs.txt.
```

**Unknown reference:**
```
Reference 'Order' in Pizza.order_id not found. Available aggregates: Customer, Account.
```

**Missing policy event:**
```
Policy NotifyKitchen in Pizza references unknown event: Cooked.
Known events: CreatedPizza, UpdatedPizza.
```

**Missing policy trigger:**
```
Policy NotifyKitchen in Pizza triggers unknown command: Cook.
Available commands: CreatePizza, UpdatePizza.
```

**Bidirectional reference:**
```
Bidirectional reference between Pizza and Order. Remove the reference from
one side — in DDD, only one aggregate should hold the reference. Use a
domain-level policy to coordinate.
```

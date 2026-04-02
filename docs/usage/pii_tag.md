# PII Attribute Tag

Tag aggregate attributes as PII (Personally Identifiable Information) via the
hecksagon capabilities DSL. Tagged attributes are automatically redacted in
`inspect` output and tracked in the runtime PII compliance report.

## DSL

Use the `capabilities` block inside `Hecks.hecksagon` to tag attributes with
the `.privacy` concern. This expands into `:pii`, `:encrypted`, and `:masked`
tags.

```ruby
# In your Hecksagon file
Hecks.hecksagon do
  capabilities "Customer" do
    email.privacy
    ssn.privacy
  end
end
```

Tags are chainable -- add more concerns after `.privacy`:

```ruby
capabilities "Customer" do
  email.privacy.searchable
end
```

## Runtime behavior

When a hecksagon with PII capabilities is loaded, the runtime:

1. Marks matching `RuntimeAttributeDefinition` entries with `pii: true`
2. Redacts PII values in `#inspect` output using `Hecks::PII.mask`
3. Registers a `pii_filter` middleware on the command bus
4. Exposes a `pii_report` method on the runtime

### Inspect redaction

```ruby
customer = Customer.create(name: "Alice", email: "alice@example.com", ssn: "123-45-6789")
customer.inspect
# => #<Customer id:abc12345 name: "Alice" email: a***************m ssn: 1*********9>
```

### PII compliance report

```ruby
runtime = Hecks.boot(__dir__)
runtime.pii_report
# => { "Customer" => ["email", "ssn"] }
```

## Querying PII attributes from the IR

```ruby
hex = Hecks.hecksagon do
  capabilities "Customer" do
    email.privacy
    ssn.privacy
  end
end

hex.pii_attributes("Customer")  # => ["email", "ssn"]
hex.pii_attributes("Order")     # => []
```

## Backward compatibility

The `capability.` prefix still works for explicit style:

```ruby
capabilities "Customer" do
  capability.email.privacy
end
```

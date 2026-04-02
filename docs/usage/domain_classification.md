# Domain Classification

Classify domains as **core**, **supporting**, or **generic** using the
`classification` DSL keyword. This follows the strategic DDD pattern for
distinguishing where to invest the most design effort.

## DSL

```ruby
Hecks.domain "Billing" do
  classification :core

  aggregate "Invoice" do
    attribute :amount, Float
    command("CreateInvoice") { attribute :amount, Float }
  end
end
```

Valid values: `:core`, `:supporting`, `:generic`. Defaults to `:supporting`
when omitted.

## Querying

```ruby
domain = Hecks.domain("Billing") { classification :core; ... }

domain.classification  # => :core
domain.core?           # => true
domain.supporting?     # => false
domain.generic?        # => false
```

## Serializer

The `DslSerializer` emits the classification when it differs from the default:

```ruby
Hecks::DslSerializer.new(domain).serialize
# => 'Hecks.domain "Billing" do\n  classification :core\n  ...'
```

`:supporting` is omitted from serialized output since it is the default.

## Example

```ruby
require "hecks"

billing = Hecks.domain "Billing" do
  classification :core
  aggregate("Invoice") { attribute :amount, Float; command("CreateInvoice") { attribute :amount, Float } }
end

notifications = Hecks.domain "Notifications" do
  classification :generic
  aggregate("Email") { attribute :to, String; command("SendEmail") { attribute :to, String } }
end

reporting = Hecks.domain "Reporting" do
  aggregate("Report") { attribute :title, String; command("CreateReport") { attribute :title, String } }
end

puts "#{billing.name}: #{billing.classification}"        # Billing: core
puts "#{notifications.name}: #{notifications.classification}" # Notifications: generic
puts "#{reporting.name}: #{reporting.classification}"     # Reporting: supporting
```

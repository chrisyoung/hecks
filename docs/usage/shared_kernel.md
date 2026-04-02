# Shared Kernel Types

Share value objects across bounded contexts using the **shared kernel**
pattern. A kernel domain declares `shared_kernel`, and consumer domains
use `uses_kernel "Name"` to get type aliases.

## Defining a Shared Kernel

```ruby
shared = Hecks.domain "SharedTypes" do
  shared_kernel

  aggregate "Types" do
    attribute :placeholder, String

    value_object "Money" do
      attribute :amount, Integer
      attribute :currency, String
    end

    command "CreateTypes" do
      attribute :placeholder, String
    end
  end
end

# Register so consumers can find it
Hecks::SharedKernelRegistry.register("SharedTypes", shared)
```

## Consuming a Shared Kernel

```ruby
billing = Hecks.domain "Billing" do
  uses_kernel "SharedTypes"

  aggregate "Invoice" do
    attribute :total, Integer
    command "CreateInvoice" do
      attribute :total, Integer
    end
  end
end
```

## Usage at Runtime

```ruby
# Load kernel first, then consumer
Hecks.load(shared)
Hecks.load(billing)

# Type aliases are available in the consumer namespace
BillingDomain::Money
# => SharedTypesDomain::Types::Money (same class)

money = BillingDomain::Money.new(amount: 100, currency: "USD")
money.amount    # => 100
```

## SharedKernelRegistry API

```ruby
Hecks::SharedKernelRegistry.register("SharedTypes", domain)
Hecks::SharedKernelRegistry.lookup("SharedTypes")
Hecks::SharedKernelRegistry.kernel_types("SharedTypes")
Hecks::SharedKernelRegistry.registered  # => ["SharedTypes"]
Hecks::SharedKernelRegistry.clear       # for testing
```

## Key Points

- Kernel domains must be loaded before consumers
- Value objects from kernel aggregates become top-level aliases
- `shared_kernel` and `uses_kernel` are serialized in DSL round-trips
- The registry is global and must be populated before boot

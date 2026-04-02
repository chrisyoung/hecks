# Shared Kernel — Common Types Across Bounded Contexts

Share value objects and entities between bounded contexts without duplicating definitions.

## Provider domain: declare shared kernel

```ruby
pricing = Hecks.domain "Pricing" do
  shared_kernel
  expose_types "Money", "Currency"

  aggregate "Rate" do
    attribute :amount, Integer

    value_object "Money" do
      attribute :cents, Integer
      attribute :currency, String
    end

    value_object "Currency" do
      attribute :code, String
      attribute :symbol, String
    end

    command "CreateRate" do
      attribute :amount, Integer
    end
  end
end
```

## Consumer domain: use the kernel

```ruby
orders = Hecks.domain "Orders" do
  uses_kernel "Pricing"

  aggregate "Order" do
    attribute :customer_name, String
    attribute :total_cents, Integer

    command "PlaceOrder" do
      attribute :customer_name, String
      attribute :total_cents, Integer
    end
  end
end
```

## Boot both and use shared types

```ruby
Hecks.load(pricing)
Hecks.load(orders)

# The shared type is aliased into the consumer namespace
money = OrdersDomain::Money.new(cents: 999, currency: "USD")
money.cents     # => 999
money.currency  # => "USD"

# It's the same class as the provider's
OrdersDomain::Money == PricingDomain::Rate::Money  # => true
```

## Auto-expose (no explicit types)

When `expose_types` is omitted, all value objects and entities from the
kernel domain are automatically exposed:

```ruby
common = Hecks.domain "Common" do
  shared_kernel  # no expose_types -- exposes everything

  aggregate "Shared" do
    value_object "Address" do
      attribute :street, String
      attribute :city, String
    end

    value_object "PhoneNumber" do
      attribute :digits, String
    end

    command "CreateShared" do
      attribute :label, String
    end
  end
end
```

## Registry API

```ruby
Hecksagon::SharedKernelRegistry.kernel?("Pricing")     # => true
Hecksagon::SharedKernelRegistry.types_for("Pricing")    # => ["Money", "Currency"]
Hecksagon::SharedKernelRegistry.all                     # => ["Pricing"]
```

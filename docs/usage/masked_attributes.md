# Masked Attributes

Mask sensitive attribute values in all display contexts. Masked attributes
show only the last 4 characters, with the rest replaced by asterisks.

## DSL Usage

Tag an attribute directly in the domain DSL:

```ruby
Hecks.domain "Banking" do
  aggregate "Account" do
    attribute :name, String
    attribute :ssn, String, masked: true
    attribute :account_number, String, masked: true

    command "OpenAccount" do
      attribute :name, String
      attribute :ssn, String
      attribute :account_number, String
    end
  end
end
```

## Hecksagon Capability Tagging

Tag attributes as masked in the Hecksagon file:

```ruby
Hecks.hecksagon "Banking" do
  aggregate "Account" do
    capability.ssn.masked
    capability.account_number.masked
  end
end
```

## Privacy Concern Shorthand

The `:privacy` concern expands to both `:pii` and `:masked` tags:

```ruby
Hecks.hecksagon "Banking" do
  aggregate "Account" do
    capability.ssn.privacy        # expands to .pii + .masked
  end
end
```

## Masking Behavior

```ruby
Hecks::Conventions::MaskedDisplay.mask("123-45-6789")
# => "***-**-6789"

Hecks::Conventions::MaskedDisplay.mask("4111111111111111")
# => "************1111"

Hecks::Conventions::MaskedDisplay.mask(nil)
# => nil

Hecks::Conventions::MaskedDisplay.mask("AB")
# => "****"
```

Hyphens, spaces, slashes, and dots in the masked region are preserved.

## Introspection

Masked attributes are annotated in `describe` output:

```
Account

  Attributes:
    name: String
    ssn: String [masked]
    account_number: String [masked]
```

## Display Contract

The `cell_expression` method automatically wraps masked attributes:

```ruby
Hecks::Conventions::DisplayContract.cell_expression(ssn_attr, "obj", lang: :ruby)
# => "Hecks::Conventions::MaskedDisplay.mask((obj.ssn.to_s))"
```

## Web Explorer

The `RuntimeBridge#read_attribute` method accepts a `masked:` flag:

```ruby
bridge.read_attribute(obj, :ssn, masked: true)
# => "***-**-6789"
```

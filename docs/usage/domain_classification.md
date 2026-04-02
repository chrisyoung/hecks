# Domain Classification

Classify your domain as **core**, **supporting**, or **generic** using the
`classification` keyword in the domain DSL. This is a strategic DDD concept
that helps teams prioritize investment.

## DSL

```ruby
Hecks.domain "Billing" do
  classification :core

  aggregate "Invoice" do
    attribute :amount, Integer
    command "CreateInvoice" do
      attribute :amount, Integer
    end
  end
end
```

## Allowed Values

- `:core` -- the primary business differentiator (invest heavily)
- `:supporting` -- necessary but not differentiating (default)
- `:generic` -- commodity functionality (buy or use off-the-shelf)

## Usage

```ruby
domain = Hecks.domain "Billing" do
  classification :core
  # ...
end

domain.domain_classification  # => :core
domain.core?                  # => true
domain.supporting?            # => false
domain.generic?               # => false
```

## Default Behavior

When `classification` is omitted, the domain defaults to `:supporting`.

## Serialization

The `DslSerializer` emits `classification :core` or `classification :generic`
when set. The default `:supporting` is omitted to keep DSL output clean.

# Custom Concerns

User-defined governance rules that compose extensions. Custom concerns extend
the built-in world concerns (`:transparency`, `:consent`, `:privacy`,
`:security`) with domain-specific governance checks.

## Defining a Custom Concern

```ruby
Hecks.concern :hipaa_compliance do
  description "HIPAA compliance for healthcare data"
  requires_extension :pii
  requires_extension :audit

  rule "PII fields must be hidden" do |aggregate|
    aggregate.attributes.select(&:pii?).all? { |a| !a.visible? }
  end

  rule "PII aggregates need actors on commands" do |aggregate|
    next true unless aggregate.attributes.any?(&:pii?)
    aggregate.commands.all? { |cmd| !cmd.actors.empty? }
  end
end
```

## Using Custom Concerns on a Domain

Use the `concerns` keyword to declare both world and custom concerns:

```ruby
Hecks.domain "Healthcare" do
  concerns :transparency, :privacy, :hipaa_compliance

  aggregate "Patient" do
    attribute :name, String
    attribute :ssn, String, pii: true, visible: false
    command "CreatePatient" do
      attribute :name, String
      attribute :ssn, String
      actor "Doctor"
    end
  end
end
```

The `concerns` keyword automatically splits names into world concerns and
custom concerns. You can also use `world_concerns` and `concerns` together:

```ruby
world_concerns :transparency
concerns :hipaa_compliance
```

## Querying the Registry

```ruby
Hecks.custom_concerns.all    # => [Concern, ...]
Hecks.custom_concerns.names  # => [:hipaa_compliance]
Hecks.find_concern(:hipaa_compliance)  # => Concern
```

## Governance Checks

GovernanceGuard evaluates custom concerns alongside world concerns:

```ruby
domain = Hecks.domain("Health") { concerns :hipaa_compliance; ... }
result = Hecks::GovernanceGuard.new(domain).check
result.passed?      # => false
result.violations   # => [{ concern: :hipaa_compliance, message: "..." }]
```

## CLI

```
hecks concerns               # list all active concerns with rules and status
hecks validate                # includes custom concern violations
hecks validate --governance   # full governance check including custom concerns
```

## Validation Integration

Custom concern violations appear in `hecks validate` output:

```
Domain validation failed:
  - CustomConcern[hipaa_compliance]: Patient -- PII fields must be hidden
    Fix: Fix the aggregate to satisfy the 'hipaa_compliance' concern rule
```

# Custom World Goals

Define your own world goals that validate domain design against project-specific
governance rules. Custom goals integrate seamlessly with the existing
`world_goals` DSL keyword and appear in the Mother Earth Report.

## Defining a Custom Goal

```ruby
Hecks.define_goal(:audit_trail) do
  requires_extension :audit

  validate do |domain|
    domain.aggregates.flat_map do |agg|
      agg.commands.select { |c| c.actors.empty? }.map do |cmd|
        "#{agg.name}##{cmd.name} has no actor — audit trail incomplete"
      end
    end
  end
end
```

The `validate` block receives the domain IR and returns an array of violation
message strings. Return an empty array when the goal passes.

## Activating a Custom Goal

Custom goals are activated in the domain DSL exactly like built-in goals:

```ruby
Hecks.domain "Regulated" do
  world_goals :audit_trail, :transparency

  aggregate "Report" do
    attribute :title, String
    command "FileReport" do
      attribute :title, String
      actor "Auditor"
    end
  end
end
```

The goal only fires when declared via `world_goals`. Domains that omit it are
unaffected.

## Extension Requirements

Use `requires_extension` to document which runtime extensions the goal depends
on. This metadata is available on the generated rule class:

```ruby
Hecks.define_goal(:compliance) do
  requires_extension :audit
  requires_extension :logging

  validate { |domain| [] }
end

rule = Hecks::ValidationRules::WorldGoals::Compliance
instance = rule.new(domain)
instance.required_extensions  # => [:audit, :logging]
```

## Mother Earth Report

Custom goals appear in the Mother Earth Report alongside built-in goals:

```ruby
validator = Hecks::Validator.new(domain)
validator.valid?
report = validator.mother_earth_report
# => { goals_declared: [:audit_trail, :transparency],
#      passing_goals:  [:transparency],
#      failing_goals:  [:audit_trail],
#      violations:     ["Audit Trail: Report#FileReport has no actor..."] }
```

## Idempotency

Redefining a goal with the same name replaces the previous definition. This is
safe for iterative development and test isolation.

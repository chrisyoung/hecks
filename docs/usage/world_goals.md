# World Goals -- Advisory Validators

World goals are opt-in advisory validators that produce **warnings only** (never errors). They encourage better domain design without blocking compilation or validation.

## Available Goals

| Goal              | What it checks                                      |
|-------------------|-----------------------------------------------------|
| `:equity`         | Warns if only a single actor role is defined         |
| `:sustainability` | Warns if any aggregate lacks a lifecycle definition  |

## DSL Usage

```ruby
Hecks.domain "GovAI" do
  world_goals :equity, :sustainability

  actor "Admin"
  actor "Reviewer"

  aggregate "Report" do
    attribute :title, String
    attribute :status, String

    lifecycle :status, default: "draft" do
      transition "PublishReport" => "published"
      transition "ArchiveReport" => "archived"
    end

    command "CreateReport" do
      attribute :title, String
    end
    command "PublishReport" do
      attribute :title, String
    end
    command "ArchiveReport" do
      attribute :title, String
    end
  end
end
```

## Equity

The `:equity` goal warns when only a single actor role exists. A single-actor domain concentrates all authority in one role with no checks and balances.

```ruby
# Triggers equity warning -- single actor role
Hecks.domain "Monopoly" do
  world_goals :equity
  actor "Admin"

  aggregate "Config" do
    attribute :key, String
    command "UpdateConfig" do
      attribute :key, String
    end
  end
end
# Warning: Equity: only one actor role 'Admin' -- consider additional roles for equitable access
```

Adding a second actor silences the warning:

```ruby
actor "Admin"
actor "Reviewer"
# No equity warning
```

## Sustainability

The `:sustainability` goal warns when an aggregate has no lifecycle. Without a lifecycle, data accumulates indefinitely with no archival or cleanup path.

```ruby
# Triggers sustainability warning -- no lifecycle
Hecks.domain "Ephemeral" do
  world_goals :sustainability

  aggregate "Report" do
    attribute :title, String
    command "CreateReport" do
      attribute :title, String
    end
  end
end
# Warning: Sustainability: Report has no lifecycle -- consider adding one for data retention and cleanup
```

Adding a lifecycle silences the warning:

```ruby
aggregate "Report" do
  attribute :title, String
  attribute :status, String

  lifecycle :status, default: "draft" do
    transition "ArchiveReport" => "archived"
  end

  command "CreateReport" do
    attribute :title, String
  end
  command "ArchiveReport" do
    attribute :title, String
  end
end
# No sustainability warning
```

## Key Differences from World Concerns

| Aspect          | World Concerns            | World Goals               |
|-----------------|--------------------------|---------------------------|
| DSL keyword     | `world_concerns`         | `world_goals`             |
| Output          | Errors (block validation)| Warnings (advisory only)  |
| Purpose         | Enforce ethical rules    | Encourage better design   |

## Programmatic Access

```ruby
domain = Hecks.domain("Example") { ... }
validator = Hecks::Validator.new(domain)
validator.valid?
validator.warnings  # => ["Equity: ...", "Sustainability: ..."]
```

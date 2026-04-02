# World Concerns Onboarding

When creating a new project with `hecks new`, you are prompted to declare
world concerns — opt-in ethical validation rules that check your domain
design for alignment with stated values.

## Available concerns

| Concern           | What it checks                                       |
|-------------------|------------------------------------------------------|
| `:privacy`        | PII attributes must be `visible: false`              |
| `:transparency`   | Commands must emit events (no silent mutations)      |
| `:equity`         | Reserved for future equity-focused rules             |
| `:sustainability` | Reserved for future sustainability-focused rules     |
| `:consent`        | User-like aggregate commands must declare actors     |
| `:security`       | Sensitive aggregates need auth guards                |

## Interactive usage

```
$ hecks new my_app

Welcome to Hecks.

Hecks is built on the belief that software affects living beings —
humans, animals, ecosystems. The domain you're about to model will
touch some of them.

Would you like to declare world goals for this domain?

  1. Yes — walk me through them
  2. Skip for now — I'll add them later
  3. This doesn't apply to my project

> 1

Available goals: privacy, transparency, equity, sustainability, consent, security

Select goals (comma-separated, or press Enter to skip):
> privacy, consent

Domain created. World goals declared.

Created my_app/
  MyAppBluebook
  app.rb
  ...
```

Generated Bluebook:

```ruby
Hecks.domain "MyApp" do
  world_concerns :privacy, :consent

  aggregate "Example" do
    # ...
  end
end
```

## Choosing "skip for now" (option 2)

The Bluebook is generated with no `world_concerns` line. You can add one
later by editing the file directly.

## Choosing "doesn't apply" (option 3)

The Bluebook is generated with a commented-out stub as a reminder:

```ruby
Hecks.domain "MyApp" do
  # world_concerns :transparency, :consent  # add when ready

  aggregate "Example" do
    # ...
  end
end
```

## Non-interactive / CI

Use `--no-world-goals` to skip the prompt entirely:

```
$ hecks new my_app --no-world-goals
```

When stdin is not a TTY (pipes, CI), the prompt is skipped automatically.

No `world_concerns` line is included in either case.

## Invalid input

Unrecognized concern names are silently filtered. Only the six valid
concern names are kept.

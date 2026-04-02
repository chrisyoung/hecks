# Audit Capability

The audit capability records an immutable log entry for every domain event, enriched with command name, actor, and tenant context.

## Quick Start — Extension (auto-wired)

The audit extension is auto-loaded at boot. Every domain event is recorded:

```ruby
require "hecks"

app = Hecks.boot(__dir__)

Pizza.create(name: "Margherita")
Hecks.audit_log.last[:event_name]  # => "CreatedPizza"
Hecks.audit_log.last[:event_data]  # => { name: "Margherita" }
```

## Capability API — Explicit Wiring

Use the capability module for programmatic control:

```ruby
require "hecks"
require "hecks/capabilities/audit"

domain = Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end

app = Hecks.load(domain)
Hecks::Capabilities::Audit.apply(app)

Pizza.create(name: "Hawaiian")
Hecks.audit_log.size        # => 1
Hecks.audit_log.first[:event_name]  # => "CreatedPizza"
Hecks.audit_log.first[:timestamp]   # => 2026-04-02 ...
```

## Concerns DSL — Declarative Wiring

Declare concerns in the hecksagon block and the audit capability activates automatically at boot:

```ruby
Hecks.hecksagon do
  concerns :transparency, :privacy
end

app = Hecks.boot(__dir__)

# audit is wired because :transparency and :privacy both map to the audit capability
Hecks.audit_log  # => []
```

## Custom Actor/Tenant Resolvers

Pass resolvers to control how actor and tenant are extracted:

```ruby
Hecks::Capabilities::Audit.apply(app,
  actor_resolver:  -> { current_user.email },
  tenant_resolver: -> { current_tenant.slug }
)
```

## Log Entry Format

Each entry in `Hecks.audit_log` is a Hash:

| Key           | Type        | Description                        |
|---------------|-------------|------------------------------------|
| `:command`    | String/nil  | Command name (e.g., "CreatePizza") |
| `:actor`      | String/nil  | Actor identifier                   |
| `:tenant`     | String/nil  | Tenant identifier                  |
| `:timestamp`  | Time        | When the event was recorded        |
| `:event_name` | String      | Event class name (e.g., "CreatedPizza") |
| `:event_data` | Hash        | Event attributes                   |

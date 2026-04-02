# World Concerns: Equity & Sustainability

Two additional world concerns that check governance patterns in your domain.

## Equity

Warns when the domain defines only a single actor role, which concentrates
all authority in one place.

```ruby
Hecks.domain "Hospital" do
  world_concerns :equity

  actor "Admin"
  # Warning: only one actor role 'Admin' defined
  # Consider adding roles like "Doctor", "Nurse", "Patient"

  aggregate "Record" do
    attribute :data, String
    command "CreateRecord" do
      attribute :data, String
      actor "Admin"
    end
  end
end
```

Fix by adding additional roles:

```ruby
actor "Admin"
actor "Doctor"
actor "Nurse"
```

## Sustainability

Warns when aggregates lack lifecycle management or expiration attributes.
Encourages data that can be archived or expired rather than growing unboundedly.

```ruby
Hecks.domain "Sessions" do
  world_concerns :sustainability

  aggregate "Session" do
    attribute :token, String
    # Warning: no lifecycle defined
    # Warning: no expiration attribute

    command "CreateSession" do
      attribute :token, String
    end
  end
end
```

Fix by adding lifecycle and expiration:

```ruby
aggregate "Session" do
  attribute :token, String
  attribute :expires_at, DateTime

  lifecycle :status, default: "active" do
    transition "ExpireSession" => "expired"
  end

  command "CreateSession" do
    attribute :token, String
  end
  command "ExpireSession" do
    reference_to "Session"
  end
end
```

Recognized expiration attribute names: `expires_at`, `expiration`, `ttl`,
`retention`, `retired_at`, `archived_at`.

## Key Behavior

Both concerns produce **warnings only** (treated as errors by the validator
for PASS/FAIL reporting, but they are governance nudges, not hard blockers).
They only activate when explicitly declared via `world_concerns`.

# World Goals

Declare ethical and governance aspirations for your domain. Each goal activates
validation rules that check your model for alignment.

**Goals:** Mandatory (errors) — transparency, consent, privacy, security. Advisory (warnings) — equity, sustainability.

## DSL

```ruby
Hecks.domain "Healthcare" do
  world_goals :transparency, :consent, :privacy, :security, :equity, :sustainability

  actor "Doctor"
  actor "Admin"

  aggregate "Patient" do
    attribute :name, String
    attribute :ssn, String, pii: true, visible: false
    attribute :copay, Float

    invariant "copay must be reasonable" do
      # copay >= 5 && copay <= 200
    end

    command "CreatePatient" do
      attribute :name, String
      attribute :ssn, String
      actor "Admin"
    end

    command "UpdateRecord" do
      attribute :notes, String
      actor "Doctor"
    end

    command "DischargePatient" do
      # Cleanup command for sustainability goal
      attribute :discharge_reason, String
      actor "Admin"
    end
  end
end
```

## Available Goals

### `:transparency`

Every command must emit at least one domain event. Silent mutations violate
transparency because observers and audit logs cannot track changes.

**Violation:** `emits []` on a command.

### `:consent`

Commands on user-like aggregates (User, Account, Member, Customer, Patient,
Person, Profile) must declare at least one `actor`. Without an actor, there is
no record of who initiated the action.

### `:privacy`

PII attributes (marked `pii: true`) must also be `visible: false` so they are
hidden from generated UIs. Commands on aggregates that contain PII must declare
an actor for audit trails.

### `:security`

Command-level actors must be declared at the domain level with `actor "Name"`.
This prevents dangling or misspelled role references.

### `:equity` (Advisory)

Pricing or rate attributes (those containing "price", "cost", "fee", "rate", "charge",
"amount", "margin", "discount", or "markup") should be documented with invariants or
policies to make pricing logic explicit and reviewable.

**Warning:** Aggregate has pricing attributes but no documented invariants or policies.

### `:sustainability` (Advisory)

Aggregates with creation commands (Create, Add, Register, Allocate, Open, Start, Spawn)
should have matching cleanup commands (Delete, Archive, Deactivate, Close, Expire, Retire)
to complete the resource lifecycle and avoid abandoned resources.

**Warning:** Aggregate has creation commands but no corresponding cleanup commands.

## Example Validation Output
## Mother Earth Report
When world goals are declared, `hecks validate` prints a **Mother Earth Report**
after the standard validation output. Each declared goal gets a PASS/FAIL status,
and any violations are listed.

### Mandatory Goals (Errors)

```
$ hecks validate

Domain is valid

Aggregates:
  Patient
    Attributes:     name, ssn
    Commands:       CreatePatient, UpdateRecord

Mother Earth Report
  Goals declared: transparency, consent, privacy, security
  [PASS] transparency
  [PASS] consent
  [PASS] privacy
  [PASS] security
```

When violations exist:

```
$ hecks validate

Domain validation failed:
  - Transparency: Record#DeleteRecord emits no events. Commands must emit events so changes are observable.
  - Consent: Patient#UpdateRecord has no actor. Commands on user-like aggregates must declare who initiates them.

Mother Earth Report
  Goals declared: transparency, consent
  [FAIL] transparency
  [FAIL] consent

  Violations:
    - Transparency: Record#DeleteRecord emits no events. Commands must emit events so changes are observable.
    - Consent: Patient#UpdateRecord has no actor. Commands on user-like aggregates must declare who initiates them.
```

The report is also available programmatically via `Validator#mother_earth_report`:

```ruby
validator = Hecks::Validator.new(domain)
validator.valid?
report = validator.mother_earth_report
# => { goals_declared: [:transparency], violations: [...],
#      passing_goals: [], failing_goals: [:transparency] }
```

### Advisory Goals (Warnings)

```
Equity: Service has pricing attributes (price, cost) but no documented invariant or policy explaining how pricing works.
Sustainability: Session has creation commands (CreateSession) but no corresponding cleanup, archive, or delete commands.
```

## No Goals, No Rules

If you do not declare `world_goals`, none of these rules fire. They are opt-in.
The Mother Earth Report is omitted when no goals are declared.

# Hecksagon DSL Reference

The Hecksagon is the operational layer you place alongside a Bluebook.
The Bluebook defines what exists; the hecksagon defines what you care about.

The Bluebook declares aggregates, commands, events, and domain rules — pure structure,
no infrastructure assumptions. The Hecksagon says which capabilities are active, which
attributes carry semantic weight (PII, indexed, searchable), and how the domain connects
to the outside world. Neither file knows about the other; Hecks binds them at boot.

For gates, adapters, extensions, and cross-domain wiring see
[Hecksagon Reference](hecksagon_reference.md).
For CRUD capability depth see [CRUD Capability](crud_capability.md).

---

## Two-file pattern

Every Hecks project has two files side by side:

```ruby
# HealthcareBluebook — pure domain structure
Hecks.domain "Healthcare" do
  aggregate "Patient" do
    attribute :ssn,          String
    attribute :email,        String
    attribute :created_at,   DateTime
    attribute :notes,        String
    attribute :avatar,       String
    attribute :login_count,  Integer

    command "RegisterPatient" do
      attribute :ssn,   String
      attribute :email, String
    end
  end
end

# HealthcareHecksagon — operational wiring
Hecks.hecksagon "Healthcare" do
  concerns :privacy

  aggregate "Patient" do
    ssn.privacy.searchable
    email.privacy
    created_at.indexed
    notes.searchable
    avatar.attachable
    login_count.metric
  end
end
```

`Hecks.boot(__dir__)` discovers both files automatically. Any file whose name ends in
`Bluebook` is loaded as the domain definition; any file ending in `Hecksagon` is loaded
as the infrastructure wiring. You never wire them together by hand.

---

## Concerns

`concerns` is a domain-wide declaration. It tells the hecksagon which broad concerns are
active across the whole domain.

```ruby
Hecks.hecksagon "Healthcare" do
  concerns :privacy
end
```

Concerns are shorthand for a bundle of extensions. Declaring `:privacy` is equivalent to
activating the `:pii`, `:encrypted`, and `:masked` extensions — you don't have to name
each one. Users think in concerns ("this domain handles private health information"),
not plumbing ("enable the encryption extension and the masking extension").

Multiple concerns can be declared:

```ruby
Hecks.hecksagon "Healthcare" do
  concerns :privacy, :compliance
end
```

Concerns are additive. Their constituent extensions are unioned together.
See [Built-in concerns](#built-in-concerns) for the full expansion table.

---

## Attribute tags

Inside an `aggregate` block in the hecksagon, attribute tags declare semantic intent.
The syntax is bare chaining — you write the attribute name, then dot-chain the tags:

```ruby
aggregate "Patient" do
  ssn.privacy.searchable
  email.privacy
  created_at.indexed
  notes.searchable
  avatar.attachable
  login_count.metric
end
```

Each method in the chain adds a tag. The attribute must exist in the Bluebook; the
hecksagon doesn't create anything — it annotates domain nodes.

### Tag reference

| Tag | What it does |
|-----|--------------|
| `.pii` | Marks the field as personally identifiable information. Excluded from logs, audit trails, and generic exports. |
| `.encrypted` | Field is encrypted at rest. The persistence layer applies the encryption adapter. |
| `.masked` | Display value is partially hidden (e.g. `***-**-1234` for an SSN). Affects read paths and UI rendering. |
| `.indexed` | Adds a database index on this field. Speeds up lookups and sorts. |
| `.searchable` | Included in full-text search. The search extension indexes this field. |
| `.attachable` | Field stores an attachment (file, image, blob). Wires to the file storage adapter. |
| `.metric` | Field is a numeric metric. Feeds into analytics, dashboards, and aggregations. |

Tags are open: any tag name is accepted and stored in the IR. Built-in extensions respond
to the tags they know; unknown tags pass through harmlessly for custom extensions to use.

---

## Chaining

You can compose multiple tags on a single attribute by chaining:

```ruby
aggregate "Patient" do
  ssn.pii.encrypted.masked.searchable
end
```

This adds four tags to `ssn`: `:pii`, `:encrypted`, `:masked`, and `:searchable`. Each
tag in the chain is recorded independently in the IR:

```ruby
# Stored as:
[
  { attribute: "ssn", tag: :pii },
  { attribute: "ssn", tag: :encrypted },
  { attribute: "ssn", tag: :masked },
  { attribute: "ssn", tag: :searchable }
]
```

Concerns and explicit tags compose naturally. If you declare `concerns :privacy` at the
domain level and then tag `ssn.pii` on an aggregate, the aggregate-level tags supplement
the concern — they are not redundant. Concerns say "this domain cares about privacy";
attribute tags say "this field in particular needs these behaviors."

```ruby
Hecks.hecksagon "Healthcare" do
  concerns :privacy           # activates pii, encrypted, masked domain-wide

  aggregate "Patient" do
    ssn.privacy.indexed       # adds indexed on top of the concern bundle
    email.privacy             # email gets the full privacy bundle
    created_at.indexed        # indexed only — not part of any concern
  end
end
```

---

## Built-in concerns

| Concern | Expands to |
|---------|-----------|
| `:privacy` | `:pii`, `:encrypted`, `:masked` |
| `:compliance` | `:pii`, `:encrypted`, `:masked`, `:indexed` |
| `:analytics` | `:metric`, `:indexed` |
| `:search` | `:searchable`, `:indexed` |

When you use a concern name as a tag on an attribute (e.g. `ssn.privacy`), it expands
inline to its constituent tags. The chain `ssn.privacy` is equivalent to
`ssn.pii.encrypted.masked` — the concern name is syntactic sugar for the bundle.

---

## Relationship to Bluebook

The domain owns structure. The hecksagon owns wiring.

This separation is intentional. A domain aggregate is a pure model of your business — it
has no opinion about whether SSNs are encrypted or whether emails are indexed. Those
decisions depend on deployment context, compliance requirements, and infrastructure
choices that don't belong in the domain model.

The hecksagon is sparse. You only annotate what needs annotation. An aggregate with no
hecksagon entry is fully valid; it gets no tags and no extra wiring. The domain IR is
the canonical record; the hecksagon adds a second layer of metadata on top.

At boot, Hecks merges the two: domain IR is the skeleton, hecksagon tags are the muscle.
Capabilities and extensions then walk the merged IR and generate the appropriate wiring.

```
Bluebook        Hecksagon          Merged IR
--------        ---------          ---------
Patient         Patient            Patient
  ssn     +       ssn.pii    =       ssn [pii, encrypted, masked]
  email           email.pii          email [pii, encrypted, masked]
  notes           notes.searchable   notes [searchable]
```

You never write the merged form by hand. It emerges from the two source files at boot.

---

## Full runnable example

```ruby
# HealthcareBluebook
Hecks.domain "Healthcare" do
  aggregate "Patient" do
    attribute :ssn,         String
    attribute :email,       String
    attribute :created_at,  DateTime
    attribute :notes,       String
    attribute :avatar,      String
    attribute :login_count, Integer
  end
end

# HealthcareHecksagon
Hecks.hecksagon "Healthcare" do
  concerns :privacy

  aggregate "Patient" do
    ssn.privacy.searchable
    email.privacy
    created_at.indexed
    notes.searchable
    avatar.attachable
    login_count.metric
  end
end

# Boot
app = Hecks.boot(__dir__)
```

Run it:

```sh
ruby -Ilib examples/healthcare/app.rb
```

See also:
- [Hecksagon Reference](hecksagon_reference.md) — gates, adapters, extensions, tenancy
- [CRUD Capability](crud_capability.md) — auto-generated CRUD commands

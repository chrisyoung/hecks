# Optimistic Concurrency

Hecks supports optimistic concurrency control via version numbers on aggregates.
When a command declares an `expected_version` attribute, the lifecycle pipeline
checks it against the persisted aggregate's current version before persisting.
On mismatch, a `Hecks::ConcurrencyError` is raised. On match, the aggregate
version is bumped automatically.

## Defining a versioned command

Add `attribute :expected_version, Integer` to any update command:

```ruby
Hecks.domain "Documents" do
  aggregate "Document" do
    attribute :title, String
    attribute :body, String

    command "CreateDocument" do
      attribute :title, String
      attribute :body, String
    end

    command "EditDocument" do
      reference_to "Document"
      attribute :title, String
      attribute :body, String
      attribute :expected_version, Integer
    end
  end
end
```

## Using optimistic concurrency

```ruby
app = Hecks.load(domain)

# Create starts at version 0
doc = DocumentsDomain::Document.create(title: "Draft", body: "...")
doc.aggregate.version  # => 0

# Edit with correct version succeeds and bumps
result = DocumentsDomain::Document.edit(
  document: doc.id,
  title: "Final",
  body: "...",
  expected_version: 0
)
result.aggregate.version  # => 1

# Edit with stale version raises
begin
  DocumentsDomain::Document.edit(
    document: doc.id,
    title: "Conflict",
    body: "...",
    expected_version: 0
  )
rescue Hecks::ConcurrencyError => e
  e.expected_version  # => 0
  e.actual_version    # => 1
  e.aggregate_id      # => "abc-123..."
  e.message           # => "Version mismatch on DocumentsDomain::Document: expected 0, got 1"
end
```

## Opting out

Commands that do not include `expected_version` skip the version check entirely.
This preserves backward compatibility -- existing commands work unchanged.

## Error structure

`Hecks::ConcurrencyError` provides structured context for API responses:

```ruby
e.as_json
# => { error: "ConcurrencyError", message: "...",
#      expected_version: 0, actual_version: 1,
#      aggregate_id: "abc-123..." }
```

## How it works

1. Every aggregate starts at `version: 0`
2. The `VersionCheckStep` runs between `CallStep` and `PostconditionStep`
3. It looks up the persisted aggregate and compares versions
4. On match, the new aggregate's version is set and bumped
5. On mismatch, `Hecks::ConcurrencyError` is raised before persist

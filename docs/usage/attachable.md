# Attachable Attribute Tag

Tag aggregate attributes as `:attachable` in your Hecksagon file to get
per-attribute attachment methods generated at boot time.

## Hecksagon DSL

```ruby
# PatientsHecksagon
Hecks.hecksagon do
  aggregate "Patient" do
    avatar.attachable
    scan.attachable
  end
end
```

The bare `avatar.attachable` syntax works inside the `aggregate` block.
You can also use the longer `capability.avatar.attachable` form.

## Domain Setup

```ruby
Hecks.domain "Patients" do
  aggregate "Patient" do
    attribute :name, String
    command "CreatePatient" do
      attribute :name, String
    end
  end
end
```

## Generated Methods

Once booted, the aggregate class gains:

```ruby
patient = Patient.create(name: "Alice")

# Attach metadata (filename, content_type, size, etc.)
entry = Patient.attach_avatar(patient.id, filename: "photo.jpg", content_type: "image/jpeg")
# => { filename: "photo.jpg", content_type: "image/jpeg", ref_id: "abc-123..." }

# List all attachments for the attribute
Patient.avatar_attachments(patient.id)
# => [{ filename: "photo.jpg", content_type: "image/jpeg", ref_id: "abc-123..." }]
```

## Introspection

```ruby
PatientsDomain.attachable_fields
# => { "Patient" => [:avatar, :scan] }
```

## Storage

The default store is `MemoryAttachmentStore` (in-memory, suitable for
tests). The store exposes `store`, `list`, `delete`, and `clear` methods.

Access the store via the runtime:

```ruby
app = Hecks.boot(__dir__)
app.attachment_store.clear
```

## Notes

- Attachments store **metadata only** (filename, content type, size).
  Actual file bytes are handled by your storage adapter (S3, local disk, etc.).
- The `:attachable` extension auto-activates when any aggregate has
  an `attachable` tag in the hecksagon IR.

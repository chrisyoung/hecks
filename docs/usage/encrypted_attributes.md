# Encrypted Attributes

Mark sensitive attributes with `encrypted: true` to encrypt them at rest in the repository. Values are transparently encrypted on save and decrypted on find/all/query.

## DSL

```ruby
Hecks.domain "Health" do
  aggregate "Patient" do
    attribute :name, String
    attribute :ssn, String, encrypted: true
    attribute :email, String, encrypted: true

    command "RegisterPatient" do
      attribute :name, String
      attribute :ssn, String
      attribute :email, String
    end
  end
end
```

## How it works

When an aggregate has any `encrypted: true` attributes, the runtime automatically wraps its repository in an `EncryptingRepository` decorator. This decorator:

- **On save**: encrypts marked fields before passing the aggregate to the inner repo
- **On find/all/query**: decrypts marked fields in the returned aggregates
- **Nil values**: pass through without encryption

## Encryption backends

### Test (default)

When `Hecks.encryption_key` is nil (the default), a reversible Base64 encryptor is used. This is fast and deterministic -- ideal for tests.

### AES-256-GCM (production)

Set a 32-byte key to enable real encryption:

```ruby
require "openssl"
Hecks.encryption_key = OpenSSL::Random.random_bytes(32)

# Or from an environment variable:
Hecks.encryption_key = [ENV.fetch("ENCRYPTION_KEY")].pack("H*")
```

Each encrypted value includes a random IV and auth tag, Base64-encoded for safe storage in text columns.

## Runtime example

```ruby
app = Hecks.load(domain)

patient = Patient.create(name: "Alice", ssn: "123-45-6789", email: "alice@example.com")

# Decrypted transparently on find
found = Patient.find(patient.id)
found.ssn   # => "123-45-6789"
found.email # => "alice@example.com"

# Encrypted in the underlying storage
inner = Patient.instance_variable_get(:@__hecks_repo__).instance_variable_get(:@inner)
raw = inner.find(patient.id)
raw.ssn  # => Base64-encoded ciphertext
```

## Hecksagon concern expansion

The `:privacy` concern automatically enables the `:encrypted` extension alongside `:pii`:

```ruby
builder = Hecksagon::DSL::HecksagonBuilder.new("Health")
builder.concern(:privacy)
hex = builder.build
hex.extensions.map { |e| e[:name] }  # => [:pii, :encrypted]
```

## IR query

Query which attributes are encrypted on any aggregate:

```ruby
hex = Hecksagon::Structure::Hecksagon.new(name: "Health")
hex.encrypted_attributes("Patient", domain: domain)  # => [:ssn, :email]
```

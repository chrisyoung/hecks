# CQRS

Named persistence connections for read/write separation

## Install

```ruby
# Gemfile
gem "hecks_cqrs"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
CatsDomain.boot do
  persist_to :write, :sqlite
  persist_to :read, :sqlite, database: "read.db"
end
```

## Details

CQRS support for Hecks domains. Enables named persistence connections
for read/write separation. Commands route to :write, queries to :read.
Registers with the Hecks connection registry so domains can declare
multiple named adapters in their boot block.

  CatsDomain.boot do
    persist_to :write, :sqlite
    persist_to :read, :sqlite, database: "read.db"
  end

  # Access named connections:
  CatsDomain.connections[:persist][:write]
  # => { type: :sqlite }
  CatsDomain.connections[:persist][:read]
  # => { type: :sqlite, database: "read.db" }

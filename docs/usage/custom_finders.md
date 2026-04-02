# Custom Finders

Declare named repository lookup methods on aggregates. Each finder specifies
one or more attribute parameters and returns all records matching by equality.

## DSL

```ruby
Hecks.domain "Users" do
  aggregate "User" do
    attribute :name, String
    attribute :email, String
    attribute :role, String

    command "CreateUser" do
      attribute :name, String
      attribute :email, String
      attribute :role, String
    end

    finder :by_email, :email
    finder :by_role, :role
    finder :by_name_and_role, :name, :role
  end
end
```

## Usage

```ruby
app = Hecks.boot(__dir__)

User.create(name: "Alice", email: "alice@example.com", role: "admin")
User.create(name: "Bob",   email: "bob@example.com",   role: "member")

User.by_email("alice@example.com")
# => [#<User name="Alice" ...>]

User.by_role("member")
# => [#<User name="Bob" ...>]

User.by_name_and_role("Alice", "admin")
# => [#<User name="Alice" ...>]

User.by_name_and_role("Alice", "member")
# => []
```

## How it works

- **IR**: `finder :name, :param1, :param2` stores a `Finder` node on the aggregate
- **Memory adapter**: auto-generates equality-match implementations filtering `@store.values`
- **Port module**: generates `NotImplementedError` stubs so custom adapters know which methods to implement
- **Runtime**: `FinderMethods.bind` defines singleton methods on the aggregate class that delegate to the repository

## Custom adapters

When writing a SQL or other adapter, include the generated port module and
implement each finder method:

```ruby
class UserSqlRepository
  include UsersDomain::Ports::UserRepository

  def by_email(email)
    db[:users].where(email: email).map { |row| hydrate(row) }
  end
end
```

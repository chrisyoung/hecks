# Custom Finders

Declare named repository finders in the aggregate DSL. Each finder
becomes a `find_by_<name>` method on the repository, auto-implemented
by the memory adapter.

## DSL

```ruby
Hecks.domain "Users" do
  aggregate "User" do
    attribute :email, String
    attribute :username, String

    command "CreateUser" do
      attribute :email, String
      attribute :username, String
    end

    finder :email
    finder :login, attribute: :username
  end
end
```

## Usage

```ruby
app = Hecks.boot(__dir__)

User.create(email: "alice@co.com", username: "alice")

repo = app["User"]
repo.find_by_email("alice@co.com")    # => #<User email="alice@co.com" ...>
repo.find_by_login("alice")           # => #<User username="alice" ...>
repo.find_by_email("missing@co.com")  # => nil
```

## How It Works

1. `finder :email` adds a `Finder` node to the aggregate IR
2. At boot, `FinderMethods.bind` defines `find_by_email(value)` on the repo
3. The method scans `all` records for a match on the specified attribute
4. Custom adapters (SQL, Redis) can override with optimized implementations

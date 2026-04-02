# Side-Effect-Free Functions

Both aggregates and value objects can define **pure functions** -- methods
that compute a result from attributes without mutating state.

## DSL

```ruby
Hecks.domain "Contacts" do
  aggregate "Person" do
    attribute :first_name, String
    attribute :last_name, String

    function :full_name do
      "#{first_name} #{last_name}"
    end

    value_object "Address" do
      attribute :street, String
      attribute :city, String

      function :one_line do
        "#{street}, #{city}"
      end
    end

    command "CreatePerson" do
      attribute :first_name, String
      attribute :last_name, String
    end
  end
end
```

## Usage

```ruby
app = Hecks.boot(__dir__)

person = Person.create(first_name: "John", last_name: "Doe")
person.full_name  # => "John Doe"

addr = ContactsDomain::Person::Address.new(street: "123 Main", city: "Springfield")
addr.one_line     # => "123 Main, Springfield"
```

## Key Points

- `function :name do ... end` defines a side-effect-free computation
- Available on both aggregates and value objects
- Generated as plain instance methods (no mutation, no side effects)
- Differs from `computed` in that computed attributes appear in inspect/UI
- Serialized in DSL round-trips via `DslSerializer`

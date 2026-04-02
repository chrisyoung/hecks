# Pure Functions

Side-effect-free functions on aggregates and value objects.

## On Aggregates

```ruby
Hecks.domain "Contacts" do
  aggregate "Person" do
    attribute :first, String
    attribute :last, String

    function :full_name do
      "#{first} #{last}"
    end

    function :initials do
      "#{first[0]}#{last[0]}"
    end

    command "CreatePerson" do
      attribute :first, String
      attribute :last, String
    end
  end
end
```

Generated output:

```ruby
class Person
  include Hecks::Model

  attribute :first
  attribute :last

  # Pure functions -- side-effect-free
  def full_name
    "#{first} #{last}"
  end

  def initials
    "#{first[0]}#{last[0]}"
  end
end
```

## On Value Objects

```ruby
value_object "Address" do
  attribute :street, String
  attribute :city, String
  attribute :zip, String

  function :display do
    "#{street}, #{city} #{zip}"
  end
end
```

Generated output:

```ruby
class Address
  attr_reader :street, :city, :zip

  # Pure functions -- side-effect-free
  def display
    "#{street}, #{city} #{zip}"
  end
end
```

## Serializer Round-Trip

Functions survive serialization and deserialization:

```ruby
domain = Hecks.domain("Contacts") { ... }
source = Hecks::DslSerializer.new(domain).serialize
restored = eval(source)
restored.aggregates.first.functions.first.name  # => :full_name
```

## Validation

Function names must not collide with regular or computed attributes:

```ruby
aggregate "Person" do
  attribute :name, String
  function(:name) { "oops" }  # => validation error
end
```

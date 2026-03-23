# Hecks for ActiveRecord Users

You know ActiveRecord. Here's how Hecks compares.

## The familiar stuff

```ruby
# ActiveRecord                    # Hecks
Pizza.create(name: "Margherita")  Pizza.create(name: "Margherita")
Pizza.find(id)                    Pizza.find(id)
Pizza.all                         Pizza.all
Pizza.count                       Pizza.count
Pizza.first                       Pizza.first
pizza.update(name: "New")         pizza.update(name: "New")
pizza.save                        pizza.save
pizza.destroy                     pizza.destroy
```

Same API. Different engine.

## Where they diverge

### Queries

ActiveRecord scatters queries everywhere:
```ruby
# ActiveRecord — queries in controllers, services, everywhere
Pizza.where(style: "Classic").order(:name).limit(5)
```

Hecks encourages named lookups in the DSL:
```ruby
# Hecks — lookups are part of your business description
query "Classics" do
  where(style: "Classic").order(:name)
end

# Then use them cleanly
Pizza.classics
```

Want the ActiveRecord-style queries too? Opt in:
```ruby
Hecks.configure do
  domain "pizzas_domain"
  include_ad_hoc_queries  # now Pizza.where(...).order(...) works
end
```

### Callbacks → Actions + Reactions

ActiveRecord:
```ruby
class Order < ApplicationRecord
  after_create :reserve_stock
  after_create :send_notification
  before_save :validate_quantity
end
```

Hecks:
```ruby
aggregate "Order" do
  command "PlaceOrder" do
    attribute :pizza_id, reference_to("Pizza")
    attribute :quantity, Integer
  end

  # When an order is placed, reserve stock
  policy "ReserveIngredients" do
    on "PlacedOrder"
    trigger "ReserveStock"
  end
end
```

No hidden callbacks. Every cause and effect is visible in the DSL.

### Associations → References + Embedded Details

ActiveRecord:
```ruby
class Pizza < ApplicationRecord
  has_many :toppings
  belongs_to :restaurant
end
```

Hecks:
```ruby
aggregate "Pizza" do
  attribute :restaurant_id, reference_to("Restaurant")
  attribute :toppings, list_of("Topping")

  value_object "Topping" do
    attribute :name, String
    attribute :amount, Integer
  end
end
```

References are by ID (not objects). Toppings are embedded details that live inside the Pizza.

### Migrations

ActiveRecord:
```bash
rails generate migration CreatePizzas name:string style:string
rake db:migrate
```

Hecks:
```bash
hecks generate:migrations
hecks db:migrate
```

Hecks auto-generates migrations from your DSL changes. No manual column definitions.

### Testing

ActiveRecord:
```ruby
# Need database, fixtures, seeds, cleanup
let(:pizza) { Pizza.create!(name: "Test") }
```

Hecks:
```ruby
# No database needed — memory by default
app = Hecks::Services::Application.new(domain)
Pizza.create(name: "Test")
```

Tests run against memory. No database process, no migrations, no fixtures.

## The big differences

| | ActiveRecord | Hecks |
|---|---|---|
| **Your model is** | A database table wrapper | A pure Ruby class |
| **Persistence** | Baked into every object | Plugged in from outside |
| **Business rules** | Mixed with callbacks and validations | In the DSL, enforced at build time |
| **Database** | One database, configured in database.yml | Any database, one config line |
| **Testing** | Needs database | Runs in memory |
| **Sharing** | Copy model files between apps | Publish a gem, add to Gemfile |
| **Events** | Roll your own or add a gem | Built in, automatic |
| **Event sourcing** | Not supported | One flag: `event_sourced: true` |

## Switching from ActiveRecord

1. Describe your models in a Hecks DSL file
2. Run `hecks build` to generate the domain gem
3. Add the gem to your Rails Gemfile
4. Add `config/initializers/hecks.rb`:

```ruby
Hecks.configure do
  domain "your_domain"
  adapter :sql, database: :postgres,
    host: "localhost", user: "app", name: "your_db"
  include_ad_hoc_queries  # familiar API
end
```

5. Delete your ActiveRecord models
6. Your controllers don't change

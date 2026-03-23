# Why Hecks instead of ActiveRecord?

Hecks was born out of frustration with ActiveRecord. Your model layer shouldn't be a tangle of persistence logic, callbacks, and query scopes — with business rules buried somewhere in the middle. ActiveRecord makes the database the center of your architecture. Hecks makes your domain the center. DDD and hexagonal architecture shouldn't be harder than `rails generate model` — so we made it just as easy.

## Model real-world relationships, not database tables

ActiveRecord starts with the database and works backward — your models are table wrappers. Hecks starts with how your business actually works. A Pizza has Toppings. An Order references a Pizza. You describe that in Ruby, and the database plumbing gets handled for you.

## Your domain is a gem, not a directory

Hecks generates a standalone Ruby gem with zero dependencies. Your domain is a versioned artifact — you can share it across multiple apps, test it in isolation, and reason about it without a database running.

## No persistence in your objects

A Hecks aggregate is just a Ruby class with attributes, validations, and invariants. No `belongs_to`, no `has_many`, no callbacks, no `before_save`. You don't need plumbing that's just for databases mixed into your business logic.

## Tests don't need a database

Your domain runs against memory adapters by default — no migrations, no fixtures, no database process. Production uses SQL. The domain code is identical either way.

## Queries are domain concepts

Instead of scattering `where` clauses across controllers and services, you define named queries in the DSL:

```ruby
aggregate "Order" do
  query "Pending" do
    where(status: "pending")
  end

  query "ForPizza" do |pizza_id|
    where(pizza_id: pizza_id)
  end
end
```

`Order.pending` and `Order.for_pizza(id)` are part of your domain language, not ad-hoc SQL. ActiveRecord-style queries (`where`, `order`, `limit`) are available as an opt-in for when you need them:

```ruby
Hecks.configure do
  domain "pizzas_domain"
  include_ad_hoc_queries  # enables Pizza.where(...).order(...).limit(...)
end
```

## Commands make intent explicit

Instead of `pizza.update(status: "cancelled")`, you define `CancelOrder` — a named command that fires a `CancelledOrder` event. Every state change has a name, a payload, and a paper trail.

## Any database, zero lock-in

Configure your database in one line. Sequel handles MySQL, Postgres, and SQLite behind the scenes:

```ruby
Hecks.configure do
  domain "pizzas_domain"
  adapter :sql, database: :mysql,
    host: "localhost", user: "root", password: "secret", name: "pizzas"
end
```

Switch databases by changing the config. Your domain code never touches SQL.

## Still feels like ActiveRecord when you want it to

With `include_ad_hoc_queries`, you get the familiar API:

```ruby
Pizza.where(style: "Classic").order(:name).limit(5)
Pizza.find_by(name: "Margherita")
Pizza.order(name: :desc).offset(10)
Pizza.where(price: gt(10))
pizza.save
pizza.update(name: "New")
pizza.destroy
```

No excuses.

---

Even simple CRUD apps have a domain. Hecks just makes you model it first and pick a database later — instead of the other way around.

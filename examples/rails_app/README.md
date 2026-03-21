# Hecks Pizza Shop — Rails Example

A real Rails 7 app using a Hecks domain gem. No ActiveRecord models — domain objects come from the `pizzas_domain` gem and work with all Rails helpers out of the box.

## Setup

The domain gem is pre-built in `pizzas_domain/`. To recreate it from scratch:

```bash
# From the hecks project root
cd examples/pizzas
hecks build
cp -r pizzas_domain ../rails_app/
```

Then:

```bash
cd examples/rails_app
bundle install
rails generate active_hecks:init
rails server
```

## What `active_hecks:init` Creates

- `config/initializers/hecks.rb` — configures the domain gem and adapter
- `app/models/HECKS_README.md` — explains why there are no model files
- Adds `require "hecks/test_helper"` to your spec/test helper for automatic cleanup between tests

## How It Works

The initializer uses `Hecks.configure`:

```ruby
Hecks.configure do
  domain "pizzas_domain"
  adapter :memory    # or :sql for ActiveRecord-backed persistence
end
```

The Railtie boots the Application container after initializers load. This wires
commands, repositories, events, and hoists aggregate constants. Domain objects
come from the gem only — there are no model files in `app/models/`.

After that, domain objects just work:

```ruby
# Controllers
Pizza.create(name: "Margherita", description: "Classic")
Pizza.find(id)
Pizza.all
Pizza.where(name: "Margherita")
Pizza.first
Pizza.last
Pizza.delete(id)

pizza.update(name: "New Name")
pizza.save
pizza.destroy

pizza.toppings.create(name: "Mozzarella", amount: 2)
pizza.toppings.first.delete

Order.place(pizza_id: id, quantity: 3)

# Command bus middleware
APP.use :logging do |cmd, next_handler|
  Rails.logger.info("Command: #{cmd.class.name}")
  next_handler.call
end

# Views
form_with(model: @pizza) { |f| f.text_field :name }
link_to @pizza.name, pizza_path(@pizza)
```

## Testing

`active_hecks:init` automatically adds the test helper to your spec helper:

```ruby
require "hecks/test_helper"
```

This resets all memory adapter stores and event history between each test,
so every spec starts with a clean slate.

## Updating the Domain

1. Go to the Hecks project where `domain.rb` lives
2. `hecks console` to edit interactively
3. `hecks build` to generate a new version
4. Copy the updated gem into this app
5. Generate and run migrations for any schema changes:
   ```bash
   rails generate active_hecks:migration    # produces db/hecks_migrate/*.sql
   rake hecks:db:migrate             # applies pending migrations
   ```
6. Restart the Rails server

## Pages

| URL | What it does |
|---|---|
| `/` | List all pizzas |
| `/pizzas/new` | Create a pizza |
| `/pizzas/:id` | Show a pizza |
| `/pizzas/:id/edit` | Edit a pizza |
| `/pizzas/:id/orders/new` | Order a pizza |
| `/orders` | List all orders |

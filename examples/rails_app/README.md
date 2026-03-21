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
rails generate hecks:init
rails server
```

## What `hecks:init` Creates

- `config/initializers/hecks.rb` — loads the domain gem, boots the Application container, activates ActiveModel
- `app/models/HECKS_README.md` — explains why there are no model files

## How It Works

The initializer does three things:

```ruby
# 1. Load the domain definition from the gem
DOMAIN = eval(File.read(gem_path + "/domain.rb"))

# 2. Boot the Application container (wires commands, repos, events)
APP = Hecks::Services::Application.new(DOMAIN)

# 3. Activate ActiveModel for form helpers
Hecks::Rails.activate(PizzasDomain)
```

After that, domain objects just work:

```ruby
# Controllers
Pizza.create(name: "Margherita", description: "Classic")
Pizza.find(id)
Pizza.all
Pizza.delete(id)
Order.place(pizza_id: id, quantity: 3)
pizza.toppings.create(name: "Mozzarella", amount: 2)

# Views
form_with(model: @pizza) { |f| f.text_field :name }
link_to @pizza.name, pizza_path(@pizza)
```

## Updating the Domain

1. Go to the Hecks project where `domain.rb` lives
2. `hecks console` to edit interactively
3. `hecks build` to generate a new version
4. Copy the updated gem into this app
5. Restart the Rails server

## Pages

| URL | What it does |
|---|---|
| `/` | List all pizzas |
| `/pizzas/new` | Create a pizza |
| `/pizzas/:id` | Show a pizza |
| `/pizzas/:id/edit` | Edit a pizza |
| `/pizzas/:id/orders/new` | Order a pizza |
| `/orders` | List all orders |

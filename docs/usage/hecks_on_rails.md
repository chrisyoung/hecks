# Rails Setup

## Install

```ruby
# Gemfile
gem "hecks_on_rails"
gem "pizzas_domain"
```

```bash
bundle install
rails generate active_hecks:init
```

The generator detects your domain gem and wires up everything:
ActionCable, Turbo Streams, importmap, live events, test helpers.

See [Generators](rails_generators.md) for details on what each generator does.

## Domain Objects in Controllers

No models directory needed. Domain objects work like ActiveRecord:

```ruby
class PizzasController < ApplicationController
  def index
    @pizzas = Pizza.all
  end

  def create
    @pizza = Pizza.create(name: params[:name], price: params[:price].to_i)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to pizzas_path }
    end
  end

  def destroy
    Pizza.delete(params[:id])
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to pizzas_path }
    end
  end
end
```

## Domain Objects in Views

```erb
<%= form_with url: pizzas_path do |f| %>
  <%= f.text_field :name %>
  <%= f.submit %>
<% end %>

<%= button_to "Delete", pizza_path(pizza), method: :delete %>

<%= pizza.name %>
<%= pizza.valid? %>
<%= pizza.errors[:name] %>
```

Path helpers, `form_with`, `button_to`, `to_param` — all work.

## Multi-Domain

Add multiple domain gems to your Gemfile. Hecks auto-detects all `*_domain` gems:

```ruby
gem "pizzas_domain"
gem "billing_domain"
gem "shipping_domain"
```

Each domain's aggregates are available as top-level classes.

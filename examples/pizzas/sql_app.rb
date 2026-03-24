#!/usr/bin/env ruby
#
# Example: Using the SQL adapter with a Pizzas domain (Sequel + SQLite)
#
# Run from the hecks project root:
#   ruby -Ilib examples/pizzas/sql_app.rb

require "hecks"
require "sequel"

# 1. Load and build the domain
domain_file = File.join(__dir__, "hecks_domain.rb")
domain = eval(File.read(domain_file), nil, domain_file, 1)
output = Hecks.build(domain, version: "2026.03.23.1", output_dir: __dir__)

$LOAD_PATH.unshift(File.join(output, "lib"))
require "pizzas_domain"
Dir[File.join(output, "lib/**/*.rb")].sort.each { |f| load f }

# 2. Generate SQL adapters
mod = domain.module_name + "Domain"
domain.aggregates.each do |agg|
  gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: mod)
  eval(gen.generate, TOPLEVEL_BINDING)
end

# 3. Create SQLite database with Sequel
db = Sequel.sqlite

db.create_table(:pizzas) do
  String :id, primary_key: true, size: 36
  String :name; String :description
  String :created_at; String :updated_at
end

db.create_table(:pizzas_toppings) do
  String :id, primary_key: true, size: 36
  String :pizza_id, null: false
  String :name; Integer :amount
end

db.create_table(:orders) do
  String :id, primary_key: true, size: 36
  String :pizza_id; Integer :quantity; String :status
  String :created_at; String :updated_at
end

# 4. Wire the app with SQL adapters
pizza_repo = PizzasDomain::Adapters::PizzaSqlRepository.new(db)
order_repo = PizzasDomain::Adapters::OrderSqlRepository.new(db)

app = Hecks::Services::Runtime.new(domain) do
  adapter "Pizza", pizza_repo
  adapter "Order", order_repo
end

# Subscribe to events
app.on("CreatedPizza") { |e| puts "  [event] CreatedPizza: #{e.name}" }
app.on("PlacedOrder") { |e| puts "  [event] PlacedOrder: quantity=#{e.quantity}" }

# 5. Use it
puts "=== SQLite Demo (via Sequel) ==="
puts

puts "Creating pizzas..."
Pizza.create(name: "Margherita", description: "Classic")
Pizza.create(name: "Pepperoni", description: "Spicy")

# Save with toppings
topping1 = PizzasDomain::Pizza::Topping.new(name: "Mozzarella", amount: 2)
topping2 = PizzasDomain::Pizza::Topping.new(name: "Basil", amount: 1)
pizza = PizzasDomain::Pizza.new(name: "Caprese", description: "Fresh", toppings: [topping1, topping2])
app["Pizza"].save(pizza)
puts "\nSaved Caprese with #{pizza.toppings.size} toppings"

# Read back with toppings from join table
found = Pizza.find(pizza.id)
puts "Found: #{found.name} (#{found.toppings.size} toppings)"
found.toppings.each { |t| puts "  - #{t.name} x#{t.amount}" }

# Place an order
puts "\nPlacing order..."
Order.place(pizza_id: pizza.id, quantity: 5)

# Query
puts "\nAll pizzas:"
Pizza.all.each { |p| puts "  #{p.name}: #{p.description}" }
puts "Total: #{Pizza.count}"

# Named query
puts "\nClassic pizzas:"
Pizza.by_description("Classic").each { |p| puts "  #{p.name}" }

# Delete
Pizza.delete(pizza.id)
puts "\nAfter deleting Caprese: #{Pizza.count} pizzas"

# Events
puts "\n=== Event Log ==="
app.events.each_with_index do |event, i|
  puts "#{i + 1}. #{event.class.name.split('::').last} at #{event.occurred_at}"
end

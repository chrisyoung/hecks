#!/usr/bin/env ruby
#
# Example: Using the SQL adapter with a Pizzas domain (Sequel + SQLite)
#
# Run from the hecks project root:
#   ruby -Ilib examples/pizzas/sql_app.rb

require "hecks"

app = Hecks.boot(__dir__, adapter: :sqlite)

# Subscribe to events
app.on("CreatedPizza") { |e| puts "  [event] CreatedPizza: #{e.name}" }
app.on("PlacedOrder") { |e| puts "  [event] PlacedOrder: quantity=#{e.quantity}" }

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
Order.place(pizza: pizza, quantity: 5)

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

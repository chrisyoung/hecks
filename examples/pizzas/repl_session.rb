#!/usr/bin/env ruby
#
# Example: Interactive REPL-style domain building
#
# Run from the hecks project root:
#   ruby -Ilib examples/pizzas/repl_session.rb

require "hecks"

# Start a session
session = Hecks.session("Pizzas")

# Build the Pizza aggregate incrementally
pizza = session.aggregate("Pizza")
pizza.attr :name, String
pizza.attr :description, String
pizza.attr :toppings, pizza.list_of("Topping")

pizza.value_object "Topping" do
  attribute :name, String
  attribute :amount, Integer
end

pizza.validation :name, presence: true

pizza.command "CreatePizza" do
  attribute :name, String
  attribute :description, String
end

# Build the Order aggregate
order = session.aggregate("Order")
order.attr :pizza, order.reference_to("Pizza")
order.attr :quantity, Integer

order.command "PlaceOrder" do
  attribute :pizza, reference_to("Pizza")
  attribute :quantity, Integer
end

order.command "ReserveStock" do
  attribute :pizza, reference_to("Pizza")
  attribute :quantity, Integer
end

order.policy "ReserveIngredients" do
  on "PlacedOrder"
  trigger "ReserveStock"
end

# Review
puts "\n=== Describe Pizza ==="
pizza.describe

puts "\n=== Describe Order ==="
order.describe

puts "\n=== Full Domain ==="
session.describe

# Validate
puts "=== Validate ==="
session.validate

# Preview generated code
puts "\n=== Preview Pizza ==="
pizza.preview

# Switch to play mode
puts "\n=== Play Mode ==="
session.play!

session.commands.each { |c| puts "  #{c}" }

puts ""
session.execute("CreatePizza", name: "Margherita", description: "Classic")
puts ""
session.execute("PlaceOrder", pizza: "pizza-123", quantity: 2)

puts "\n=== Event History ==="
session.history

# Save the domain definition
puts "\n=== Generated DSL ==="
puts session.to_dsl

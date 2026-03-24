#!/usr/bin/env ruby
#
# Example: Multiple domains sharing an event bus
#
# Three separate domain gems — pizzas, billing, shipping — each with their
# own things and actions. When an order is placed in pizzas, billing creates
# an invoice and shipping creates a shipment automatically via reactions.
#
# Run from the hecks project root:
#   ruby -Ilib examples/multi_domain/app.rb

require "hecks"

# 1. Load each domain
domains = %w[pizzas billing shipping].map do |name|
  path = File.join(__dir__, "#{name}_domain.rb")
  eval(File.read(path), nil, path, 1)
end

# 2. Validate all domains
domains.each do |domain|
  valid, errors = Hecks.validate(domain)
  puts "#{domain.name} valid: #{valid}"
  errors.each { |e| puts "  - #{e}" } unless valid
end

# 3. Build all gems
domains.each do |domain|
  output = Hecks.build(domain, output_dir: __dir__)
  lib_path = File.join(output, "lib")
  $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
  require domain.gem_name
end

# 4. Boot with shared event bus
shared_bus = Hecks::EventBus.new

apps = domains.map do |domain|
  Hecks::Runtime.new(domain, event_bus: shared_bus)
end

# 5. Subscribe to events across all domains
shared_bus.subscribe("PlacedOrder") do |event|
  puts "  [event] PlacedOrder: pizza_id=#{event.pizza_id}, quantity=#{event.quantity}"
end

shared_bus.subscribe("CreatedInvoice") do |event|
  puts "  [event] CreatedInvoice: pizza_id=#{event.pizza_id}, quantity=#{event.quantity}"
end

shared_bus.subscribe("CreatedShipment") do |event|
  puts "  [event] CreatedShipment: pizza_id=#{event.pizza_id}, quantity=#{event.quantity}"
end

# 6. Create a pizza and place an order
puts "\n--- Creating a pizza ---"
margherita = Pizza.create(name: "Margherita", style: "Classic", price: 12.0)
puts "Created: #{margherita.name} ($#{margherita.price})"

puts "\n--- Placing an order ---"
puts "Watch what happens across all three domains:"
Order.place(pizza_id: margherita.id, quantity: 3)

# 7. Check pizzas domain state
puts "\n--- Pizzas domain ---"
puts "Pizzas: #{Pizza.count}"
puts "Orders: #{Order.count}"

# 8. Show the shared event history — events flow across all domains
puts "\n--- Shared event history ---"
shared_bus.events.each_with_index do |event, i|
  name = event.class.name.split("::").last
  puts "#{i + 1}. #{name} at #{event.occurred_at}"
end

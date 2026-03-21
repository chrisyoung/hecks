#!/usr/bin/env ruby
#
# Example: Using the SQL adapter with a Pizzas domain
#
# Run from the hecks project root:
#   ruby -Ilib examples/pizzas/sql_app.rb
#
# Requires: gem install sqlite3

require "hecks"

# 1. Load and build the domain (CalVer auto-stamped)
domain = eval(File.read(File.join(__dir__, "domain.rb")))
output = Hecks.build(domain, version: "2026.03.20.1", output_dir: __dir__)

$LOAD_PATH.unshift(File.join(output, "lib"))
require "pizzas_domain"

# 2. Generate SQL schema and adapters
mod = domain.module_name + "Domain"
gem_dir = output

migration_gen = Hecks::Generators::SqlMigrationGenerator.new(domain)
schema = migration_gen.generate

domain.aggregates.each do |agg|
  adapter_gen = Hecks::Generators::SqlAdapterGenerator.new(agg, domain_module: mod)
  path = File.join(gem_dir, "lib/pizzas_domain/adapters/#{agg.name.downcase}_sql_repository.rb")
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, adapter_gen.generate)
end

# Reload to pick up new adapters
Dir[File.join(gem_dir, "lib/**/*.rb")].sort.each { |f| load f }

# 3. Show what was generated
puts "=== Generated SQL Schema ==="
puts schema
puts

puts "=== Generated SQL Adapter (Pizza) ==="
puts File.read(File.join(gem_dir, "lib/pizzas_domain/adapters/pizza_sql_repository.rb"))
puts

puts "=== Generated SQL Adapter (Order) ==="
puts File.read(File.join(gem_dir, "lib/pizzas_domain/adapters/order_sql_repository.rb"))
puts

# 4. Use it with SQLite (if available)
begin
  require "sqlite3"

  db = SQLite3::Database.new(":memory:")
  db.results_as_hash = true

  # Run the migration
  schema.split(";").each do |stmt|
    stmt = stmt.strip
    db.execute(stmt) unless stmt.empty?
  end

  puts "=== Live SQLite Demo ==="
  puts

  # Wire the app with SQL adapter instances (pass the connection)
  pizza_repo = PizzasDomain::Adapters::PizzaSqlRepository.new(db)
  order_repo = PizzasDomain::Adapters::OrderSqlRepository.new(db)

  app = Hecks::Services::Application.new(domain) do
    adapter "Pizza", pizza_repo
    adapter "Order", order_repo
  end

  # Subscribe to events
  app.on("CreatedPizza") { |e| puts "  [event] CreatedPizza: #{e.name}" }
  app.on("PlacedOrder") { |e| puts "  [event] PlacedOrder: quantity=#{e.quantity}" }

  # Create some pizzas using the short API
  puts "Creating pizzas..."
  Pizza.create(name: "Margherita", description: "Classic tomato and mozzarella")
  Pizza.create(name: "Pepperoni", description: "Spicy pepperoni")

  # Save a pizza with toppings directly via the repo
  topping1 = PizzasDomain::Pizza::Topping.new(name: "Mozzarella", amount: 2)
  topping2 = PizzasDomain::Pizza::Topping.new(name: "Basil", amount: 1)
  pizza = PizzasDomain::Pizza.new(
    name: "Caprese",
    description: "Fresh and light",
    toppings: [topping1, topping2]
  )
  app["Pizza"].save(pizza)
  puts "\nSaved Caprese with #{pizza.toppings.size} toppings"

  # Read it back with toppings hydrated from the join table
  found = Pizza.find(pizza.id)
  puts "Found: #{found.name} (#{found.toppings.size} toppings)"
  found.toppings.each do |t|
    puts "  - #{t.name} x#{t.amount}"
  end

  # Place an order using the short API
  puts "\nPlacing order..."
  Order.place(pizza_id: pizza.id, quantity: 5)

  # Query using aggregate class methods
  puts "\nAll pizzas in database:"
  Pizza.all.each do |p|
    puts "  #{p.name}: #{p.description} (#{p.toppings.size} toppings)"
  end
  puts "Total: #{Pizza.count}"

  puts "\nAll orders in database:"
  Order.all.each do |o|
    puts "  order #{o.id[0..7]}... pizza_id=#{o.pizza_id} qty=#{o.quantity}"
  end

  # Delete
  Pizza.delete(pizza.id)
  puts "\nAfter deleting Caprese: #{Pizza.count} pizzas"

  # Event log
  puts "\n=== Event Log ==="
  app.events.each_with_index do |event, i|
    name = event.class.name.split("::").last
    puts "#{i + 1}. #{name} at #{event.occurred_at}"
  end

rescue LoadError
  puts "=== SQLite not installed ==="
  puts "To run the live demo: gem install sqlite3"
  puts "The generated schema and adapters above show what would be used."
end

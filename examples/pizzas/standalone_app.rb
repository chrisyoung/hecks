#!/usr/bin/env ruby
#
# Standalone Pizzas Domain — HTTP Server
#
# First generate the standalone gem:
#   ruby -Ihecks_model/lib -Ihecks_domain/lib -Ihecks_runtime/lib -Ihecksties/lib -e "
#     require 'hecks'
#     domain = eval(File.read('examples/pizzas/hecks_domain.rb'), nil, 'hecks_domain.rb', 1)
#     Hecks.build_standalone(domain, output_dir: 'tmp')
#   "
#
# Then run this example (no hecks required):
#   ruby -Itmp/pizzas_domain/lib examples/pizzas/standalone_app.rb
#
# Try it:
#   curl -X POST http://localhost:9292/pizzas/create_pizza \
#     -H 'Content-Type: application/json' \
#     -d '{"name":"Margherita","description":"Classic"}'
#
#   curl http://localhost:9292/pizzas
#   curl http://localhost:9292/_openapi

require "pizzas_domain"

# Seed some data
Pizza.create_pizza(name: "Margherita", description: "Classic")
Pizza.create_pizza(name: "Pepperoni", description: "Spicy")

puts "Seeded #{Pizza.count} pizzas"
puts ""

# Start HTTP server
PizzasDomain.serve(port: 9292)

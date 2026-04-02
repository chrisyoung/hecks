# HecksCrud
#
# Opt-in CRUD extension that generates Create, Update, and Delete commands
# for each aggregate that does not already define them. When enabled, the
# extension introspects the domain IR, builds missing command and event IR
# nodes, generates Ruby source in memory, and re-wires the runtime ports.
#
# This is a driven extension -- it fires before driving adapters (HTTP, etc.)
# so that generated commands are visible to route builders and API docs.
#
# Usage:
#   require "hecks/extensions/crud"
#
#   app = Hecks.boot(__dir__, adapter: :memory)
#   # Pizza.create, Pizza.update, Pizza.delete are now available
#
#   # Or in a Bluebook:
#   Hecks.domain "Pizzas" do
#     aggregate "Pizza" do
#       attribute :name, String
#     end
#   end
#   app = Hecks.load(domain)
#   # No CRUD commands yet -- extension must be explicitly enabled
#
require_relative "crud/command_generator"

Hecks.describe_extension(:crud,
  description: "Auto-generate Create/Update/Delete commands for aggregates",
  adapter_type: :driven,
  config: {},
  wires_to: :command_bus)

Hecks.register_extension(:crud) do |domain_mod, domain, runtime|
  Hecks::Crud::CommandGenerator.generate_all(domain_mod, domain, runtime)
end

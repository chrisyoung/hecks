# Hecksagon
#
# Hexagonal architecture wiring DSL for Hecks. Declares infrastructure
# concerns separately from domain modeling: gates (access control),
# adapters (persistence), extensions, cross-domain subscriptions,
# and tenancy.
#
# The Hecksagon file sits alongside the Bluebook (domain definition)
# and is loaded during boot to wire the domain into its runtime
# infrastructure.
#
#   Hecks.hecksagon "Pizzas" do
#     adapter :sqlite, database: "pizzas.db"
#     gate "Pizza", :admin do
#       allow :find, :all, :create_pizza
#     end
#   end
#
module Hecksagon
  module DSL
    autoload :HecksagonBuilder, "hecksagon/dsl/hecksagon_builder"
    autoload :GateBuilder,      "hecksagon/dsl/gate_builder"
  end

  module Structure
    autoload :Hecksagon,      "hecksagon/structure/hecksagon"
    autoload :GateDefinition, "hecksagon/structure/gate_definition"
  end
end

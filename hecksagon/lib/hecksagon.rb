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
#   Hecks.hecksagon do
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

  # Legacy heksagons functionality (merged from heksagons/ gem)
  autoload :StrategicDSL,     "hecksagon/strategic_dsl"
  autoload :DomainMixin,      "hecksagon/domain_mixin"
  autoload :ExtensionsDSL,    "hecksagon/extensions_dsl"
  autoload :AclBuilder,       "hecksagon/acl_builder"
  autoload :AdapterRegistry,  "hecksagon/adapter_registry"
  autoload :ContractValidator, "hecksagon/contract_validator"

  # Post-load injection: include StrategicDSL into DomainBuilder after both
  # bluebook and hecksagon are loaded (bluebook defines DomainBuilder first,
  # hecksagon loads second, so the `if defined?` guard in the class body fires
  # too early).
  def self.inject_strategic_dsl!
    return unless defined?(Hecks::DSL::DomainBuilder)
    return if Hecks::DSL::DomainBuilder.include?(StrategicDSL)

    Hecks::DSL::DomainBuilder.include(StrategicDSL)
  end
end

Hecksagon.inject_strategic_dsl!

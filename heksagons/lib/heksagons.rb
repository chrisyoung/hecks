# Heksagons
#
# Hexagonal architecture for Hecks. The structural glue that makes
# any modeling grammar pluggable.
#
# Provides:
#   driving_port  — inbound interfaces (HTTP, MCP, CLI, events)
#   driven_port   — outbound dependencies (persistence, notifications)
#
# The domain is the hexagon. Ports are the edges. Adapters are outside.
#
#   Hecks.domain "Orders" do
#     driving_port :http, description: "REST API"
#     driven_port :persistence, [:find, :save, :delete, :all]
#   end
#
require_relative "heksagons/extensions_dsl"
require_relative "heksagons/strategic_dsl"
require_relative "heksagons/acl_builder"
require_relative "heksagons/domain_mixin"

module Heksagons
  VERSION = "0.1.0"
end

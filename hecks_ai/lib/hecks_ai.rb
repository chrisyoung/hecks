# = HecksAi
#
# MCP server and AI tools for Hecks. Provides aggregate building,
# domain inspection, play mode, and build tools via MCP protocol.
#
module Hecks
  module AI
    autoload :McpServer,        "hecks_ai/mcp_server"
    autoload :AggregateTools,   "hecks_ai/aggregate_tools"
    autoload :BuildTools,       "hecks_ai/build_tools"
    autoload :InspectTools,     "hecks_ai/inspect_tools"
    autoload :PlayTools,        "hecks_ai/play_tools"
    autoload :SessionTools,     "hecks_ai/session_tools"
    autoload :DomainSerializer, "hecks_ai/domain_serializer"
    autoload :DomainServer,     "hecks_ai/domain_server"
    autoload :Connection,       "hecks_ai/connection"
  end
end

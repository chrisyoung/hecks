# HecksAi
#
# MCP (Model Context Protocol) server connection for Hecks domains.
# Exposes domain commands, queries, and session tools to AI agents.
#
# Future gem: hecks_ai
#
#   require "hecks_ai"
#   Hecks::McpServer.new.run
#
module Hecks
  module MCP
    autoload :DomainServer,  "hecks_ai/domain_server"
    autoload :SessionTools,  "hecks_ai/session_tools"
    autoload :AggregateTools, "hecks_ai/aggregate_tools"
    autoload :InspectTools,  "hecks_ai/inspect_tools"
    autoload :BuildTools,    "hecks_ai/build_tools"
    autoload :PlayTools,     "hecks_ai/play_tools"
  end

  module Connections
    autoload :McpConnection, "hecks_ai/connection"
  end

  autoload :McpServer, "hecks_ai/mcp_server"
end

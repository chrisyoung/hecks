# Hecks::Connections
#
# External connections that plug into domains. HTTP servers, MCP servers,
# and custom adapters live here. Everything outside the domain boundary
# is a connection.
#
#   lib/hecks/connections/
#     http/          — REST + SSE server, OpenAPI, JSON-RPC
#     mcp/           — MCP domain server, tool modules
#     mcp_server.rb  — standalone MCP session server
#
module Hecks
  module Connections
  end
end

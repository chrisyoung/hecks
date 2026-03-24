# Hecks::Connections::McpConnection
#
# Wraps the MCP server as a listens_to connection.
# Starts a stdio MCP server exposing domain commands/queries as tools.
#
#   listens_to :mcp, transport: :stdio
#
module Hecks
  module Connections
    class McpConnection
      def initialize(domain, runtime)
        @server = MCP::DomainServer.new(domain)
      end

      def start
        @server.run
      end
    end
  end
end

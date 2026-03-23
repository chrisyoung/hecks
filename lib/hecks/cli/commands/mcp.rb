# Hecks::CLI mcp command
#
module Hecks
  class CLI < Thor
    desc "mcp", "Start the MCP server for AI agents to build domains"
    def mcp
      require_relative "../../mcp_server"
      McpServer.new.run
    end
  end
end

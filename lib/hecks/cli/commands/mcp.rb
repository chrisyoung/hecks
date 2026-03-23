# Hecks::CLI mcp command
#
module Hecks
  class CLI < Thor
    desc "mcp [DOMAIN]", "Start MCP server — build domains (no args) or serve one"
    def mcp(domain_path = nil)
      if domain_path
        domain = resolve_domain(domain_path)
        unless domain
          say "Domain not found: #{domain_path}", :red
          return
        end
        require_relative "../../mcp/domain_server"
        MCP::DomainServer.new(domain).run
      else
        require_relative "../../mcp_server"
        McpServer.new.run
      end
    end
  end
end

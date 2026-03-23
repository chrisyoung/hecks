# Hecks::CLI serve commands
#
module Hecks
  class CLI < Thor
    desc "serve DOMAIN", "Serve a domain as HTTP (default) or MCP (--mcp)"
    option :port, type: :numeric, default: 9292, desc: "HTTP port"
    option :mcp, type: :boolean, default: false, desc: "Use MCP instead of HTTP"
    def serve(domain_path = nil)
      domain = resolve_domain(domain_path)
      unless domain
        say "No domain found. Pass a path or run from a directory with domain.rb", :red
        return
      end
      if options[:mcp]
        require_relative "../../mcp/domain_server"
        MCP::DomainServer.new(domain).run
      else
        require_relative "../../http/domain_server"
        HTTP::DomainServer.new(domain, port: options[:port]).run
      end
    end
  end
end

# Hecks::CLI serve command
#
module Hecks
  class CLI < Thor
    desc "serve DOMAIN", "Serve a domain (HTTP default, --mcp, --rpc)"
    option :port, type: :numeric, default: 9292, desc: "HTTP port"
    option :mcp, type: :boolean, default: false, desc: "MCP for AI agents"
    option :rpc, type: :boolean, default: false, desc: "JSON-RPC"
    def serve(domain_path = nil)
      domain = resolve_domain(domain_path)
      unless domain
        say "No domain found. Pass a path or run from a directory with domain.rb", :red
        return
      end
      if options[:mcp]
        require_relative "../../mcp/domain_server"
        MCP::DomainServer.new(domain).run
      elsif options[:rpc]
        require_relative "../../http/rpc_server"
        HTTP::RpcServer.new(domain, port: options[:port]).run
      else
        require_relative "../../http/domain_server"
        HTTP::DomainServer.new(domain, port: options[:port]).run
      end
    end
  end
end

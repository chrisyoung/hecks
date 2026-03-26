# Hecks::CLI::Domain#serve
#
# Serves a domain over HTTP. By default starts a REST + SSE server via
# HTTP::DomainServer. With --rpc, starts a JSON-RPC server via HTTP::RpcServer.
# With --live, also starts a WebSocket server via HecksSockets.
#
#   hecks domain serve [--domain NAME] [--port 9292] [--rpc] [--live]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "serve", "Serve a domain as HTTP (default) or JSON-RPC (--rpc)"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      option :port, type: :numeric, default: 9292, desc: "HTTP port"
      option :rpc, type: :boolean, default: false, desc: "JSON-RPC"
      option :live, type: :boolean, default: false, desc: "WebSocket server"
      option :live_port, type: :numeric, default: 9293, desc: "WebSocket port"
      def serve
        domain = resolve_domain_option
        return unless domain
        if options[:rpc]
          require "hecks_serve"
          HTTP::RpcServer.new(domain, port: options[:port]).run
        else
          require "hecks_serve"
          server = HTTP::DomainServer.new(domain, port: options[:port],
            live: options[:live], live_port: options[:live_port])
          server.run
        end
      end
    end
  end
end

# Hecks::CLI serve command
#
module Hecks
  class CLI < Thor
    desc "serve", "Serve a domain as HTTP (default) or JSON-RPC (--rpc)"
    option :domain, type: :string, desc: "Domain gem name or path"
    option :version, type: :string, desc: "Domain version"
    option :port, type: :numeric, default: 9292, desc: "HTTP port"
    option :rpc, type: :boolean, default: false, desc: "JSON-RPC"
    def serve
      domain = resolve_domain_option
      return unless domain
      if options[:rpc]
        require_relative "../../http/rpc_server"
        HTTP::RpcServer.new(domain, port: options[:port]).run
      else
        require_relative "../../http/domain_server"
        HTTP::DomainServer.new(domain, port: options[:port]).run
      end
    end
  end
end

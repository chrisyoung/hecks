# HecksServe
#
# HTTP and JSON-RPC server connection for Hecks domains.
# Serves domains over REST and JSON-RPC via WEBrick. Includes
# OpenAPI, JSON Schema, and RPC discovery generators.
#
# Future gem: hecks_serve
#
#   require "hecks_serve"
#   Hecks::HTTP::DomainServer.new(domain, port: 3000).run
#
Hecks.describe_extension(:http,
  description: "REST and JSON-RPC server with OpenAPI docs",
  config: { port: { default: 9292, desc: "HTTP port" }, rpc: { default: false, desc: "Enable JSON-RPC mode" } },
  wires_to: :command_bus)

Hecks.register_extension(:http) do |domain_mod, domain, _runtime|
  domain_mod.define_singleton_method(:serve) do |port: 9292|
    Hecks::HTTP::DomainServer.new(domain, port: port).run
  end
end

module Hecks
  module HTTP
    autoload :DomainServer,       "hecks/extensions/serve/domain_server"
    autoload :RpcServer,          "hecks/extensions/serve/rpc_server"
    autoload :RouteBuilder,       "hecks/extensions/serve/route_builder"
    autoload :OpenapiGenerator,   "hecks/generators/docs/openapi_generator"
    autoload :RpcDiscovery,       "hecks/generators/docs/rpc_discovery"
    autoload :JsonSchemaGenerator, "hecks/generators/docs/json_schema_generator"
  end

  module Connections
    autoload :HttpConnection, "hecks/extensions/serve/connection"
  end
end

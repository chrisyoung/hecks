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
module Hecks
  module HTTP
    autoload :DomainServer,       "hecks_serve/domain_server"
    autoload :RpcServer,          "hecks_serve/rpc_server"
    autoload :RouteBuilder,       "hecks_serve/route_builder"
    autoload :OpenapiGenerator,   "hecks_serve/openapi_generator"
    autoload :RpcDiscovery,       "hecks_serve/rpc_discovery"
    autoload :JsonSchemaGenerator, "hecks_serve/json_schema_generator"
  end

  module Connections
    autoload :HttpConnection, "hecks_serve/connection"
  end
end

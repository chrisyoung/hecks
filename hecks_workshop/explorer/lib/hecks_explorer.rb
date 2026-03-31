# = HecksExplorer
#
# Web explorer for Hecks domains. HTML views, renderer, HTTP server,
# route builder, and JSON-RPC server.
#
module Hecks
  module Explorer
    VIEWS_DIR = File.join(__dir__, "hecks_explorer", "views")

    autoload :Renderer,             "hecks_explorer/renderer"
    autoload :DomainServer,         "hecks_explorer/domain_server"
    autoload :MultiDomainServer,    "hecks_explorer/multi_domain_server"
    autoload :MultiDomainUiRoutes,  "hecks_explorer/multi_domain_ui_routes"
    autoload :RouteBuilder,         "hecks_explorer/route_builder"
    autoload :RpcServer,            "hecks_explorer/rpc_server"
    autoload :Connection,           "hecks_explorer/connection"
  end
end

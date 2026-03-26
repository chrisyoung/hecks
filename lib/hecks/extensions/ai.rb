# HecksAi
#
# MCP (Model Context Protocol) server connection for Hecks domains.
# Exposes domain commands, queries, and session tools to AI agents.
#
# Future gem: hecks_ai
#
#   require "hecks_ai"
#   Hecks::McpServer.new.run
#
Hecks.describe_extension(:mcp,
  description: "MCP server for AI-assisted domain modeling",
  config: { port: { default: 8080, desc: "MCP server port" } },
  wires_to: :domain)

Hecks.register_extension(:mcp) do |domain_mod, domain, _runtime|
  domain_mod.define_singleton_method(:mcp) do |**opts|
    Hecks::McpServer.new(**opts).run
  end
end

module Hecks
  module MCP
    autoload :DomainServer,  "hecks/extensions/ai/domain_server"
    autoload :SessionTools,  "hecks/extensions/ai/session_tools"
    autoload :AggregateTools, "hecks/extensions/ai/aggregate_tools"
    autoload :InspectTools,  "hecks/extensions/ai/inspect_tools"
    autoload :BuildTools,    "hecks/extensions/ai/build_tools"
    autoload :PlayTools,     "hecks/extensions/ai/play_tools"
  end

  module Connections
    autoload :McpConnection, "hecks/extensions/ai/connection"
  end

  autoload :McpServer, "hecks/extensions/ai/mcp_server"
end

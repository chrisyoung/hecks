# Hecks::MCP::SessionTools
#
# MCP tools for session management. A session is the entry point for
# domain modeling -- it must be created or loaded before any other tools
# can be used. These tools set +ctx.session+ on the shared McpServer context.
#
# Registered tools:
#   - +create_session+ -- start a new blank domain modeling session with a name
#   - +load_domain+    -- load an existing domain.rb file and reconstruct the
#     session from its aggregates and attributes
#
module Hecks
  module MCP
    module SessionTools
      # Registers session management tools on the given MCP server.
      #
      # @param server [MCP::Server] the MCP server instance to register tools on
      # @param ctx [Hecks::McpServer] the shared context; +ctx.session+ will be
      #   set when either tool is invoked
      # @return [void]
      def self.register(server, ctx)
        server.define_tool(
          name: "create_session",
          description: "Create a new domain modeling session",
          input_schema: { type: "object", properties: { name: { type: "string", description: "Domain name (e.g. Pizzas)" } }, required: ["name"] }
        ) do |args|
          ctx.session = Hecks.session(args["name"])
          "Session created: #{args["name"]}"
        end

        server.define_tool(
          name: "load_domain",
          description: "Load an existing domain.rb file",
          input_schema: { type: "object", properties: { path: { type: "string", description: "Path to domain.rb" } }, required: ["path"] }
        ) do |args|
          Kernel.load(args["path"])
          domain = Hecks.last_domain
          ctx.session = Hecks.session(domain.name)
          domain.aggregates.each do |agg|
            handle = ctx.session.aggregate(agg.name)
            agg.attributes.each { |a| handle.attr(a.name, a.type) }
          end
          "Loaded: #{domain.name} (#{domain.aggregates.map(&:name).join(', ')})"
        end
      end
    end
  end
end

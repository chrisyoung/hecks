# Hecks::MCP::SessionTools
#
# MCP tools for creating and loading domain sessions.
#
module Hecks
  module MCP
    module SessionTools
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
          domain = eval(File.read(args["path"]), TOPLEVEL_BINDING, args["path"])
          ctx.session = Hecks.session(domain.name)
          domain.aggregates.each do |agg|
            handle = ctx.session.aggregate(agg.name)
            agg.attributes.each { |a| handle.add_attribute(a.name, a.type) }
          end
          "Loaded: #{domain.name} (#{domain.aggregates.map(&:name).join(', ')})"
        end
      end
    end
  end
end

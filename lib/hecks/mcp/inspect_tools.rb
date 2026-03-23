# Hecks::MCP::InspectTools
#
# MCP tools for reading domain state: describe the full domain, list
# aggregates, preview generated Ruby code, and show raw DSL source.
#
module Hecks
  module MCP
    module InspectTools
      def self.register(server, ctx)
        server.define_tool(
          name: "describe_domain",
          description: "Show everything in the domain",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.capture_output { ctx.session.describe }
        end

        server.define_tool(
          name: "list_aggregates",
          description: "List all things in the domain",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.session.aggregates.join(", ")
        end

        server.define_tool(
          name: "preview_code",
          description: "Show generated Ruby code",
          input_schema: { type: "object", properties: { aggregate: { type: "string" } } }
        ) do |args|
          ctx.ensure_session!
          ctx.capture_output { ctx.session.preview(args["aggregate"]) }
        end

        server.define_tool(
          name: "show_dsl",
          description: "Show the domain DSL source",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.session.to_dsl
        end
      end
    end
  end
end

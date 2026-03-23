# Hecks::MCP::BuildTools
#
# MCP tools for validating, building, and saving domains.
#
module Hecks
  module MCP
    module BuildTools
      def self.register(server, ctx)
        server.define_tool(
          name: "validate",
          description: "Check the domain for errors",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.capture_output { ctx.session.validate }
        end

        server.define_tool(
          name: "build_gem",
          description: "Generate the domain gem",
          input_schema: { type: "object", properties: { output_dir: { type: "string" } } }
        ) do |args|
          ctx.ensure_session!
          path = ctx.session.build(output_dir: args["output_dir"] || ".")
          "Built: #{path}"
        end

        server.define_tool(
          name: "save_dsl",
          description: "Save domain DSL to a file",
          input_schema: { type: "object", properties: { path: { type: "string" } } }
        ) do |args|
          ctx.ensure_session!
          ctx.session.save(args["path"] || "domain.rb")
          "Saved to #{args["path"] || "domain.rb"}"
        end
      end
    end
  end
end

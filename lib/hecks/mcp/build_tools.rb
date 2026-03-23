# Hecks::MCP::BuildTools
#
# MCP tools for validating, building, saving, and serving domains.
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

        server.define_tool(
          name: "serve_domain",
          description: "Serve the domain as HTTP REST API with SSE events",
          input_schema: { type: "object", properties: { port: { type: "integer", description: "Port (default 9292)" } } }
        ) do |args|
          ctx.ensure_session!
          domain = ctx.session.send(:to_domain)
          require_relative "../http/domain_server"
          port = args["port"] || 9292
          Thread.new { Hecks::HTTP::DomainServer.new(domain, port: port).run }
          "Serving domain on http://localhost:#{port}"
        end
      end
    end
  end
end

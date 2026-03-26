# Hecks::MCP::BuildTools
#
# MCP tools for domain lifecycle operations: validate the domain model,
# generate the domain gem, save the DSL source to a file, and serve the
# domain as an HTTP REST API with SSE events.
#
# All tools require an active session (enforced via +ctx.ensure_session!+).
#
# Registered tools:
#   - +validate+      -- check the domain for structural errors
#   - +build_gem+     -- generate a Ruby gem from the domain model
#   - +save_dsl+      -- persist the domain DSL to a .rb file
#   - +serve_domain+  -- start an HTTP server exposing the domain as REST endpoints
#
module Hecks
  module MCP
    module BuildTools
      # Registers all build/lifecycle tools on the given MCP server.
      #
      # @param server [MCP::Server] the MCP server instance to register tools on
      # @param ctx [Hecks::McpServer] the shared context providing session access,
      #   +ensure_session!+, and +capture_output+ helpers
      # @return [void]
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
          ctx.session.save(args["path"] || "hecks_domain.rb")
          "Saved to #{args["path"] || "hecks_domain.rb"}"
        end

        server.define_tool(
          name: "serve_domain",
          description: "Serve the domain as HTTP REST API with SSE events",
          input_schema: { type: "object", properties: { port: { type: "integer", description: "Port (default 9292)" } } }
        ) do |args|
          ctx.ensure_session!
          domain = ctx.session.send(:to_domain)
          require "hecks_serve"
          port = args["port"] || 9292
          Thread.new { Hecks::HTTP::DomainServer.new(domain, port: port).run }
          "Serving domain on http://localhost:#{port}"
        end
      end
    end
  end
end

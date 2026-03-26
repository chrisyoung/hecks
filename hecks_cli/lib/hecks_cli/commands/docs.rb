# Hecks::CLI::Domain#docs, Domain#readme
#
# Starts a WEBrick server hosting Swagger UI for a domain's API.
# Generates OpenAPI 3.0 and JSON-RPC discovery specs on the fly and serves
# them alongside an HTML page that loads Swagger UI from a CDN.
#
# The readme subcommand generates README.md from docs/readme_template.md
# by replacing {{tags}} with content from docs/content/, docs/usage/,
# and auto-generated tables from code.
#
#   hecks domain docs [--domain NAME] [--port 9393]
#   hecks domain readme
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "readme", "Generate README.md and extension docs"
      # Generates README.md from the template and extension-specific documentation.
      #
      # Uses ReadmeGenerator to process docs/readme_template.md and
      # ExtensionDocs to generate per-extension README files.
      #
      # @return [void]
      def readme
        require "hecks/domain/readme_generator"
        root = Dir.pwd
        ReadmeGenerator.new(root).generate
        say "Generated README.md", :green

        files = Hecks::ExtensionDocs.generate_readmes(root)
        files.each { |f| say "Generated #{f}", :green }
      end

      desc "docs", "Serve API documentation (Swagger UI)"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      option :port, type: :numeric, default: 9393, desc: "Port"
      # Starts a WEBrick HTTP server serving Swagger UI for the domain's API.
      #
      # Generates OpenAPI 3.0 and JSON-RPC discovery specs from the domain
      # model and serves them as JSON endpoints. The root path serves an HTML
      # page that loads Swagger UI from a CDN pointing at /openapi.json.
      #
      # @return [void] runs until interrupted with Ctrl-C
      def docs
        domain = resolve_domain_option
        return unless domain

        require "hecks_serve"
        require "webrick"
        require "json"

        openapi = HTTP::OpenapiGenerator.new(domain).generate
        rpc = HTTP::RpcDiscovery.new(domain).generate
        port = options[:port]

        say "Hecks docs for #{domain.name} on http://localhost:#{port}", :green
        say "  GET /              Swagger UI"
        say "  GET /openapi.json  OpenAPI 3.0 spec"
        say "  GET /rpc_methods.json  JSON-RPC discovery"

        server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
        server.mount_proc("/openapi.json") { |_, res| res["Content-Type"] = "application/json"; res["Access-Control-Allow-Origin"] = "*"; res.body = JSON.generate(openapi) }
        server.mount_proc("/rpc_methods.json") { |_, res| res["Content-Type"] = "application/json"; res["Access-Control-Allow-Origin"] = "*"; res.body = JSON.generate(rpc) }
        server.mount_proc("/") { |_, res| res["Content-Type"] = "text/html"; res.body = swagger_html(port) }
        trap("INT") { server.shutdown }
        server.start
      end

      private

      # Generates the HTML page that loads Swagger UI from a CDN.
      #
      # @param port [Integer] the server port, used to construct the OpenAPI URL
      # @return [String] the HTML content
      def swagger_html(port)
        <<~HTML
          <!DOCTYPE html>
          <html><head><title>Hecks API Docs</title>
          <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist/swagger-ui.css">
          </head><body>
          <div id="swagger-ui"></div>
          <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist/swagger-ui-bundle.js"></script>
          <script>SwaggerUIBundle({url: "http://localhost:#{port}/openapi.json", dom_id: '#swagger-ui'})</script>
          </body></html>
        HTML
      end
    end
  end
end

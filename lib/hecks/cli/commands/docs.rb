# Hecks::CLI docs commands
#
module Hecks
  class CLI < Thor
    desc "generate:docs", "Generate OpenAPI and RPC discovery docs"
    map "generate:docs" => :generate_docs
    def generate_docs
      domain_file = find_domain_file
      unless domain_file
        say "No domain.rb found in current directory", :red
        return
      end
      domain = load_domain(domain_file)

      require_relative "../../http/openapi_generator"
      require_relative "../../http/rpc_discovery"

      FileUtils.mkdir_p("docs")

      openapi = HTTP::OpenapiGenerator.new(domain).generate
      File.write("docs/openapi.json", JSON.pretty_generate(openapi))
      say "Generated docs/openapi.json", :green

      rpc = HTTP::RpcDiscovery.new(domain).generate
      File.write("docs/rpc_methods.json", JSON.pretty_generate(rpc))
      say "Generated docs/rpc_methods.json", :green
    end

    desc "docs [DOMAIN]", "Serve API documentation (Swagger UI)"
    option :port, type: :numeric, default: 9393, desc: "Port"
    def docs(domain_path = nil)
      domain = resolve_domain(domain_path)
      unless domain
        say "No domain found", :red
        return
      end

      require_relative "../../http/openapi_generator"
      require_relative "../../http/rpc_discovery"
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

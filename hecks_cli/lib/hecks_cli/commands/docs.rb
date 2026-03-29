Hecks::CLI.register_command(:readme, "Generate README.md and extension docs", group: "Domain Tools") do
  require "hecks/domain/readme_generator"
  root = Dir.pwd
  Hecks::ReadmeGenerator.new(root).generate
  say "Generated README.md", :green

  files = Hecks::ExtensionDocs.generate_readmes(root)
  files.each { |f| say "Generated #{f}", :green }
end

Hecks::CLI.register_command(:serve_docs, "Serve API documentation (Swagger UI)",
  group: "Domain Tools", options: {
    domain:  { type: :string,  desc: "Domain gem name or path" },
    version: { type: :string,  desc: "Domain version" },
    port:    { type: :numeric, default: 9393, desc: "Port" }
  }
) do
  domain = resolve_domain_option
  next unless domain

  require "hecks_serve"
  require "webrick"
  require "json"

  openapi = Hecks::HTTP::OpenapiGenerator.new(domain).generate
  rpc = Hecks::HTTP::RpcDiscovery.new(domain).generate
  port = options[:port]

  swagger_html = lambda do |p|
    <<~HTML
      <!DOCTYPE html>
      <html><head><title>Hecks API Docs</title>
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist/swagger-ui.css">
      </head><body>
      <div id="swagger-ui"></div>
      <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist/swagger-ui-bundle.js"></script>
      <script>SwaggerUIBundle({url: "http://localhost:#{p}/openapi.json", dom_id: '#swagger-ui'})</script>
      </body></html>
    HTML
  end

  say "Hecks docs for #{domain.name} on http://localhost:#{port}", :green
  say "  GET /              Swagger UI"
  say "  GET /openapi.json  OpenAPI 3.0 spec"
  say "  GET /rpc_methods.json  JSON-RPC discovery"

  server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
  server.mount_proc("/openapi.json") { |_, res| res["Content-Type"] = "application/json"; res["Access-Control-Allow-Origin"] = "*"; res.body = JSON.generate(openapi) }
  server.mount_proc("/rpc_methods.json") { |_, res| res["Content-Type"] = "application/json"; res["Access-Control-Allow-Origin"] = "*"; res.body = JSON.generate(rpc) }
  server.mount_proc("/") { |_, res| res["Content-Type"] = "text/html"; res.body = swagger_html.call(port) }
  trap("INT") { server.shutdown }
  server.start
end

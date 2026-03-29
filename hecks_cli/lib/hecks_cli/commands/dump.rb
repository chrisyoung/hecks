Hecks::CLI.register_command(:dump, "Extract docs from a domain (schema, swagger, rpc, domain, glossary)",
  options: {
    domain:  { type: :string, desc: "Domain gem name or path" },
    version: { type: :string, desc: "Domain version" }
  },
  args: ["TYPE"]
) do |type = nil|
  domain = resolve_domain_option
  next unless domain

  ask_dump_type = lambda do
    say "What would you like to dump?"
    say "  1. schema    — JSON Schema (all types and commands)"
    say "  2. swagger   — OpenAPI 3.0 spec"
    say "  3. rpc       — JSON-RPC discovery"
    say "  4. domain    — domain gem to domain/ folder"
    say "  5. glossary  — plain-English domain glossary"
    { "1" => "schema", "2" => "swagger", "3" => "rpc", "4" => "domain", "5" => "glossary" }[ask("Choice [1-5]:")]
  end

  dump_file = lambda do |d, t|
    require "hecks_serve"
    case t
    when "schema"
      File.write("schema.json", JSON.pretty_generate(Hecks::HTTP::JsonSchemaGenerator.new(d).generate))
      say "Dumped schema.json", :green
    when "swagger"
      File.write("openapi.json", JSON.pretty_generate(Hecks::HTTP::OpenapiGenerator.new(d).generate))
      say "Dumped openapi.json", :green
    when "rpc"
      File.write("rpc_methods.json", JSON.pretty_generate(Hecks::HTTP::RpcDiscovery.new(d).generate))
      say "Dumped rpc_methods.json", :green
    end
  end

  dump_domain = lambda do |d|
    FileUtils.mkdir_p("domain")
    gem_path = Hecks.build(d, output_dir: "domain")
    say "Dumped domain gem to domain/#{File.basename(gem_path)}/", :green
  end

  dump_glossary = lambda do |d|
    glossary = Hecks::DomainGlossary.new(d)
    File.write("glossary.md", glossary.generate.join("\n") + "\n")
    say "Dumped glossary.md", :green
  end

  type ||= ask_dump_type.call
  next unless type

  case type
  when "schema"   then dump_file.call(domain, "schema")
  when "swagger"  then dump_file.call(domain, "swagger")
  when "rpc"      then dump_file.call(domain, "rpc")
  when "domain"   then dump_domain.call(domain)
  when "glossary" then dump_glossary.call(domain)
  else say "Unknown type: #{type}. Use: schema, swagger, rpc, domain, glossary", :red
  end
end

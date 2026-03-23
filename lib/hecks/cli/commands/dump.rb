# Hecks::CLI dump command
#
module Hecks
  class CLI < Thor
    desc "dump [TYPE]", "Extract docs from a domain (schema, swagger, rpc, domain)"
    option :domain, type: :string, desc: "Domain gem name or path"
    option :version, type: :string, desc: "Domain version"
    def dump(type = nil)
      domain = resolve_domain_option
      return unless domain

      type ||= ask_dump_type
      return unless type

      case type
      when "schema"   then dump_file(domain, "schema")
      when "swagger"  then dump_file(domain, "swagger")
      when "rpc"      then dump_file(domain, "rpc")
      when "domain"   then dump_domain(domain)
      when "glossary" then dump_glossary(domain)
      else say "Unknown type: #{type}. Use: schema, swagger, rpc, domain, glossary", :red
      end
    end

    private

    def ask_dump_type
      say "What would you like to dump?"
      say "  1. schema    — JSON Schema (all types and commands)"
      say "  2. swagger   — OpenAPI 3.0 spec"
      say "  3. rpc       — JSON-RPC discovery"
      say "  4. domain    — domain gem to domain/ folder"
      say "  5. glossary  — plain-English domain glossary"
      { "1" => "schema", "2" => "swagger", "3" => "rpc", "4" => "domain", "5" => "glossary" }[ask("Choice [1-5]:")]
    end

    def dump_file(domain, type)
      require_relative "../../http/json_schema_generator"
      require_relative "../../http/openapi_generator"
      require_relative "../../http/rpc_discovery"
      case type
      when "schema"
        File.write("schema.json", JSON.pretty_generate(HTTP::JsonSchemaGenerator.new(domain).generate))
        say "Dumped schema.json", :green
      when "swagger"
        File.write("openapi.json", JSON.pretty_generate(HTTP::OpenapiGenerator.new(domain).generate))
        say "Dumped openapi.json", :green
      when "rpc"
        File.write("rpc_methods.json", JSON.pretty_generate(HTTP::RpcDiscovery.new(domain).generate))
        say "Dumped rpc_methods.json", :green
      end
    end

    def dump_domain(domain)
      FileUtils.mkdir_p("domain")
      gem_path = Hecks.build(domain, output_dir: "domain")
      say "Dumped domain gem to domain/#{File.basename(gem_path)}/", :green
    end

    def dump_glossary(domain)
      glossary = DomainGlossary.new(domain)
      File.write("glossary.md", glossary.generate.join("\n") + "\n")
      say "Dumped glossary.md", :green
    end
  end
end

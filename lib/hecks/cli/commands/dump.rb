# Hecks::CLI dump command
#
module Hecks
  class CLI < Thor
    desc "dump DOMAIN [TYPE]", "Extract docs from a built domain gem"
    long_desc <<~DESC
      Extract generated docs from a domain gem to the working directory.

      Types: schema, swagger, rpc, domain

      If no type given, prompts for selection.
    DESC
    def dump(domain_path, type = nil)
      domain = resolve_domain(domain_path)
      unless domain
        say "Domain not found: #{domain_path}", :red
        return
      end

      type ||= ask_dump_type
      return unless type

      case type
      when "schema"
        dump_file(domain, "schema")
      when "swagger"
        dump_file(domain, "swagger")
      when "rpc"
        dump_file(domain, "rpc")
      when "domain"
        dump_domain(domain, domain_path)
      else
        say "Unknown type: #{type}. Use: schema, swagger, rpc, domain", :red
      end
    end

    private

    def ask_dump_type
      say "What would you like to dump?"
      say "  1. schema    — JSON Schema (all types and commands)"
      say "  2. swagger   — OpenAPI 3.0 spec"
      say "  3. rpc       — JSON-RPC discovery"
      say "  4. domain    — domain gem to domain/ folder"
      choice = ask("Choice [1-4]:")
      { "1" => "schema", "2" => "swagger", "3" => "rpc", "4" => "domain" }[choice]
    end

    def dump_file(domain, type)
      require_relative "../../http/json_schema_generator"
      require_relative "../../http/openapi_generator"
      require_relative "../../http/rpc_discovery"

      case type
      when "schema"
        data = HTTP::JsonSchemaGenerator.new(domain).generate
        File.write("schema.json", JSON.pretty_generate(data))
        say "Dumped schema.json", :green
      when "swagger"
        data = HTTP::OpenapiGenerator.new(domain).generate
        File.write("openapi.json", JSON.pretty_generate(data))
        say "Dumped openapi.json", :green
      when "rpc"
        data = HTTP::RpcDiscovery.new(domain).generate
        File.write("rpc_methods.json", JSON.pretty_generate(data))
        say "Dumped rpc_methods.json", :green
      end
    end

    def dump_domain(domain, domain_path)
      FileUtils.mkdir_p("domain")
      gem_path = Hecks.build(domain, output_dir: "domain")
      say "Dumped domain gem to domain/#{File.basename(gem_path)}/", :green
    end
  end
end

# Hecks::CLI::Domain#dump
#
# Extracts domain artifacts to the filesystem. Supports five dump types:
# schema (JSON Schema), swagger (OpenAPI 3.0), rpc (JSON-RPC discovery),
# domain (full domain gem to domain/ folder), and glossary (plain-English markdown).
#
#   hecks domain dump [schema|swagger|rpc|domain|glossary] [--domain NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "dump [TYPE]", "Extract docs from a domain (schema, swagger, rpc, domain)"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      # Dumps domain artifacts to files based on the specified type.
      #
      # If no type is given, prompts the user interactively. Supported types:
      # "schema" (JSON Schema), "swagger" (OpenAPI 3.0), "rpc" (JSON-RPC),
      # "domain" (full gem to domain/), "glossary" (markdown glossary).
      #
      # @param type [String, nil] the dump type, or nil to prompt
      # @return [void]
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

      # Prompts the user to select a dump type interactively.
      #
      # @return [String, nil] the selected type name, or nil if invalid choice
      def ask_dump_type
        say "What would you like to dump?"
        say "  1. schema    — JSON Schema (all types and commands)"
        say "  2. swagger   — OpenAPI 3.0 spec"
        say "  3. rpc       — JSON-RPC discovery"
        say "  4. domain    — domain gem to domain/ folder"
        say "  5. glossary  — plain-English domain glossary"
        { "1" => "schema", "2" => "swagger", "3" => "rpc", "4" => "domain", "5" => "glossary" }[ask("Choice [1-5]:")]
      end

      # Dumps a schema, swagger, or RPC spec to a JSON file.
      #
      # @param domain [DomainModel::Structure::Domain] the domain
      # @param type [String] one of "schema", "swagger", "rpc"
      # @return [void]
      def dump_file(domain, type)
        require "hecks_serve"
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

      # Dumps the full domain gem to a domain/ directory.
      #
      # @param domain [DomainModel::Structure::Domain] the domain
      # @return [void]
      def dump_domain(domain)
        FileUtils.mkdir_p("domain")
        gem_path = Hecks.build(domain, output_dir: "domain")
        say "Dumped domain gem to domain/#{File.basename(gem_path)}/", :green
      end

      # Dumps a plain-English domain glossary to glossary.md.
      #
      # @param domain [DomainModel::Structure::Domain] the domain
      # @return [void]
      def dump_glossary(domain)
        glossary = DomainGlossary.new(domain)
        File.write("glossary.md", glossary.generate.join("\n") + "\n")
        say "Dumped glossary.md", :green
      end
    end
  end
end

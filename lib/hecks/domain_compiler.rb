# Hecks::DomainCompiler
#
# Generates domain gems (build) and loads domains into memory (load_domain).
#
#   Hecks.build(domain, version: "2026.03.23.1")
#   Hecks.load_domain(domain)
#
module Hecks
  module DomainCompiler
    def build(domain, version: "0.1.0", output_dir: ".")
      valid, errors = validate(domain)
      unless valid
        raise Hecks::ValidationError, "Domain validation failed:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
      end

      ValidationRules::Naming::ReservedNames.reserved_attr_warnings(domain).each do |w|
        warn "[Hecks] Warning: #{w}"
      end

      generator = Generators::Infrastructure::DomainGemGenerator.new(domain, version: version, output_dir: output_dir)
      gem_path = generator.generate

      require_relative "http/openapi_generator"
      require_relative "http/rpc_discovery"
      require_relative "http/json_schema_generator"
      docs_dir = File.join(gem_path, "docs")
      FileUtils.mkdir_p(docs_dir)
      File.write(File.join(docs_dir, "openapi.json"), JSON.pretty_generate(HTTP::OpenapiGenerator.new(domain).generate))
      File.write(File.join(docs_dir, "rpc_methods.json"), JSON.pretty_generate(HTTP::RpcDiscovery.new(domain).generate))
      File.write(File.join(docs_dir, "schema.json"), JSON.pretty_generate(HTTP::JsonSchemaGenerator.new(domain).generate))
      File.write(File.join(docs_dir, "glossary.md"), DomainGlossary.new(domain).generate.join("\n") + "\n")

      gem_path
    end

    def load_domain(domain, force: false, skip_validation: false)
      mod = domain.module_name + "Domain"
      key = domain.object_id
      return Object.const_get(mod) if !force && @loaded_domains[mod] == key && Object.const_defined?(mod)

      unless skip_validation
        validator = Validator.new(domain)
        unless validator.valid?
          raise Hecks::ValidationError, "Domain validation failed:\n#{validator.errors.map { |e| "  - #{e}" }.join("\n")}"
        end
      end

      Object.send(:remove_const, mod) if Object.const_defined?(mod)
      gen = Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0")
      source = gen.generate_source
      begin
        eval(source, TOPLEVEL_BINDING, "(hecks:load:#{domain.name})")
      rescue SyntaxError, NameError => e
        raise Hecks::DomainLoadError, "Failed to load domain '#{domain.name}': #{e.message}"
      end
      @loaded_domains[mod] = key
      @domain_objects[mod] = domain
      Object.const_get(mod)
    end
  end
end

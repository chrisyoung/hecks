# Hecks — Top-level entry point for the Hecks framework.
#
require "json"

# Suppress json-schema MultiJSON deprecation from mcp gem
JSON::Validator.use_multi_json = false if defined?(JSON::Validator)

module Hecks
  class PortAccessDenied < StandardError; end
end

require_relative "hecks/autoloads"
require_relative "hecks/domain_inspector"

module Hecks
  extend DomainInspector

  @configuration = nil
  @loaded_domains = {}
  @domain_objects = {}

  def self.configure(&block)
    @configuration = Configuration.new
    @configuration.instance_eval(&block)
    @configuration.boot! unless defined?(::Rails)
    @configuration
  end

  def self.configuration
    @configuration
  end

  # DSL entry point — define a complete domain in one block
  def self.domain(name, &block)
    builder = DSL::DomainBuilder.new(name)
    builder.instance_eval(&block)
    builder.build
  end

  def self.session(name)
    Session.new(name)
  end

  # Validate a domain, returns [valid?, errors]
  def self.validate(domain)
    validator = Validator.new(domain)
    [validator.valid?, validator.errors]
  end

  # Generate a domain gem, returns the output path
  def self.build(domain, version: "0.1.0", output_dir: ".")
    valid, errors = validate(domain)
    unless valid
      raise "Domain validation failed:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
    end

    generator = Generators::Infrastructure::DomainGemGenerator.new(domain, version: version, output_dir: output_dir)
    gem_path = generator.generate

    require_relative "hecks/http/openapi_generator"
    require_relative "hecks/http/rpc_discovery"
    require_relative "hecks/http/json_schema_generator"
    docs_dir = File.join(gem_path, "docs")
    FileUtils.mkdir_p(docs_dir)
    File.write(File.join(docs_dir, "openapi.json"), JSON.pretty_generate(HTTP::OpenapiGenerator.new(domain).generate))
    File.write(File.join(docs_dir, "rpc_methods.json"), JSON.pretty_generate(HTTP::RpcDiscovery.new(domain).generate))
    File.write(File.join(docs_dir, "schema.json"), JSON.pretty_generate(HTTP::JsonSchemaGenerator.new(domain).generate))
    File.write(File.join(docs_dir, "glossary.md"), DomainGlossary.new(domain).generate.join("\n") + "\n")

    gem_path
  end

  # Load a domain into memory without file I/O
  def self.load_domain(domain, force: false, skip_validation: false)
    mod = domain.module_name + "Domain"
    key = domain.object_id
    return Object.const_get(mod) if !force && @loaded_domains[mod] == key && Object.const_defined?(mod)

    unless skip_validation
      validator = Validator.new(domain)
      unless validator.valid?
        raise "Domain validation failed:\n#{validator.errors.map { |e| "  - #{e}" }.join("\n")}"
      end
    end

    Object.send(:remove_const, mod) if Object.const_defined?(mod)
    gen = Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0")
    source = gen.generate_source
    eval(source, TOPLEVEL_BINDING, "(hecks:load:#{domain.name})")
    @loaded_domains[mod] = key
    @domain_objects[mod] = domain
    Object.const_get(mod)
  end

  # Parse an event storm document (ASCII or YAML) and produce a domain + DSL
  def self.from_event_storm(source, name: nil)
    content = File.exist?(source.to_s) ? File.read(source) : source
    yaml = source.to_s.match?(/\.ya?ml$/i) || content.match?(/\A\s*(?:domain|contexts|aggregates)\s*:/)
    result = (yaml ? EventStorm::YamlParser : EventStorm::Parser).new(content).parse
    domain_name = name || result.domain_name
    EventStorm::Result.new(
      domain: EventStorm::DomainBuilder.new(result, name: domain_name).build,
      dsl: EventStorm::DslGenerator.new(result, name: domain_name).generate,
      warnings: result.warnings
    )
  end

  # Preview generated code for an aggregate
  def self.preview(domain, aggregate_name)
    mod = domain.module_name + "Domain"
    agg = domain.aggregates.find { |a| a.name == aggregate_name }
    raise "Unknown aggregate: #{aggregate_name}" unless agg
    Generators::Domain::AggregateGenerator.new(agg, domain_module: mod).generate
  end

  require "active_hecks/railtie" if defined?(::Rails::Railtie)
end

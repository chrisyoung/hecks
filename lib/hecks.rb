# Hecks — Top-level entry point and autoload registry for the Hecks framework.
#
require "json"

module Hecks
  class PortAccessDenied < StandardError; end

  autoload :Utils,          "hecks/utils"
  autoload :VERSION,        "hecks/version"
  autoload :Configuration,  "hecks/configuration"
  autoload :CLI,            "hecks/cli"
  autoload :Session,        "hecks/session"
  autoload :Validator,      "hecks/validator"
  autoload :Versioner,      "hecks/versioner"
  autoload :Migrations,     "hecks/migrations"

  module ValidationRules
    autoload :BaseRule,    "hecks/validation_rules/base_rule"
    autoload :Naming,      "hecks/validation_rules/naming"
    autoload :References,  "hecks/validation_rules/references"
    autoload :Structure,   "hecks/validation_rules/structure"
  end
  autoload :DslSerializer,      "hecks/dsl_serializer"
  autoload :ConsoleRunner,      "hecks/console_runner"

  module DomainModel
    autoload :Behavior,  "hecks/domain_model/behavior"
    autoload :Structure, "hecks/domain_model/structure"
  end

  module DSL
    autoload :AttributeCollector, "hecks/dsl/attribute_collector"
    autoload :DomainBuilder,      "hecks/dsl/domain_builder"
    autoload :ContextBuilder,     "hecks/dsl/context_builder"
    autoload :AggregateBuilder,   "hecks/dsl/aggregate_builder"
    autoload :ValueObjectBuilder, "hecks/dsl/value_object_builder"
    autoload :CommandBuilder,     "hecks/dsl/command_builder"
    autoload :PolicyBuilder,      "hecks/dsl/policy_builder"
    autoload :AggregateRebuilder, "hecks/dsl/aggregate_rebuilder"
    autoload :PortBuilder,        "hecks/dsl/port_builder"
  end

  module Generators
    autoload :ContextAware,   "hecks/generators/context_aware"
    autoload :Domain,         "hecks/generators/domain"
    autoload :SQL,            "hecks/generators/sql"
    autoload :Infrastructure, "hecks/generators/infrastructure"
  end

  module EventStorm
    autoload :Parser,        "hecks/event_storm/parser"
    autoload :YamlParser,    "hecks/event_storm/yaml_parser"
    autoload :DomainBuilder, "hecks/event_storm/domain_builder"
    autoload :DslGenerator,  "hecks/event_storm/dsl_generator"
    autoload :Result,        "hecks/event_storm/result"
  end

  module Services
    autoload :Application,      "hecks/services/application"
    autoload :AggregateWiring,  "hecks/services/aggregate_wiring"
    autoload :EventBus,         "hecks/services/event_bus"
    autoload :ContextProxy,     "hecks/services/context_proxy"
    autoload :PortEnforcer,     "hecks/services/port_enforcer"
    autoload :Persistence,      "hecks/services/persistence"
    autoload :Querying,         "hecks/services/querying"
    autoload :Commands,         "hecks/services/commands"
  end

  # Configure Hecks for an application (typically from an initializer)
  #
  #   Hecks.configure do
  #     domain "pizzas_domain"
  #     adapter :sql
  #   end
  #
  @configuration = nil

  def self.configure(&block)
    @configuration = Configuration.new
    @configuration.instance_eval(&block)
    # In non-Rails environments, boot immediately
    @configuration.boot! unless defined?(::Rails)
    @configuration
  end

  def self.configuration
    @configuration
  end

  # DSL entry point - define a complete domain in one block
  def self.domain(name, &block)
    builder = DSL::DomainBuilder.new(name)
    builder.instance_eval(&block)
    builder.build
  end

  # Start an interactive session for incremental domain building
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

    # Generate docs and schemas alongside the gem
    require_relative "hecks/http/openapi_generator"
    require_relative "hecks/http/rpc_discovery"
    require_relative "hecks/http/json_schema_generator"
    docs_dir = File.join(gem_path, "docs")
    FileUtils.mkdir_p(docs_dir)
    File.write(File.join(docs_dir, "openapi.json"), JSON.pretty_generate(HTTP::OpenapiGenerator.new(domain).generate))
    File.write(File.join(docs_dir, "rpc_methods.json"), JSON.pretty_generate(HTTP::RpcDiscovery.new(domain).generate))
    File.write(File.join(docs_dir, "schema.json"), JSON.pretty_generate(HTTP::JsonSchemaGenerator.new(domain).generate))

    gem_path
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
    ctx_mod = nil
    agg = nil
    domain.contexts.each do |ctx|
      found = ctx.aggregates.find { |a| a.name == aggregate_name }
      next unless found
      agg = found
      ctx_mod = ctx.default? ? nil : ctx.module_name
      break
    end
    raise "Unknown aggregate: #{aggregate_name}" unless agg
    Generators::Domain::AggregateGenerator.new(agg, domain_module: mod, context_module: ctx_mod).generate
  end

  require "active_hecks/railtie" if defined?(::Rails::Railtie)
end

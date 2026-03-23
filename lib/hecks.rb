# Hecks — Top-level entry point and autoload registry for the Hecks domain
# modeling framework. Hecks.domain, Hecks.build, Hecks.from_event_storm.
#
module Hecks
  class PortAccessDenied < StandardError; end

  autoload :Utils,              "hecks/utils"
  autoload :VERSION,            "hecks/version"
  autoload :Configuration,      "hecks/configuration"
  autoload :CLI,                "hecks/cli"
  autoload :Session,            "hecks/session"
  autoload :AggregateHandle,    "hecks/aggregate_handle"
  autoload :ContextHandle,      "hecks/context_handle"
  autoload :Playground,          "hecks/playground"
  autoload :Validator,          "hecks/validator"
  autoload :Versioner,          "hecks/versioner"
  autoload :DomainDiff,         "hecks/domain_diff"
  autoload :MigrationStrategy,  "hecks/migration_strategy"
  autoload :DomainSnapshot,     "hecks/domain_snapshot"
  autoload :MigrationRunner,    "hecks/migration_runner"

  module MigrationStrategies
    autoload :SqlStrategy, "hecks/migration_strategies/sql_strategy"
  end

  module ValidationRules
    autoload :BaseRule,                  "hecks/validation_rules/base_rule"
    autoload :UniqueContextNames,        "hecks/validation_rules/unique_context_names"
    autoload :UniqueAggregateNames,      "hecks/validation_rules/unique_aggregate_names"
    autoload :NameCollisions,            "hecks/validation_rules/name_collisions"
    autoload :ValidReferences,           "hecks/validation_rules/valid_references"
    autoload :NoBidirectionalReferences, "hecks/validation_rules/no_bidirectional_references"
    autoload :NoSelfReferences,          "hecks/validation_rules/no_self_references"
    autoload :NoValueObjectReferences,   "hecks/validation_rules/no_value_object_references"
    autoload :AggregatesHaveCommands,    "hecks/validation_rules/aggregates_have_commands"
    autoload :CommandNaming,             "hecks/validation_rules/command_naming"
    autoload :CommandsHaveAttributes,    "hecks/validation_rules/commands_have_attributes"
    autoload :ValidPolicyEvents,         "hecks/validation_rules/valid_policy_events"
    autoload :ValidPolicyTriggers,       "hecks/validation_rules/valid_policy_triggers"
  end
  autoload :DslSerializer,      "hecks/dsl_serializer"
  autoload :ConsoleRunner,      "hecks/console_runner"

  module DomainModel
    autoload :Domain,          "hecks/domain_model/domain"
    autoload :BoundedContext,  "hecks/domain_model/bounded_context"
    autoload :Aggregate,       "hecks/domain_model/aggregate"
    autoload :ValueObject,  "hecks/domain_model/value_object"
    autoload :Attribute,    "hecks/domain_model/attribute"
    autoload :Command,      "hecks/domain_model/command"
    autoload :DomainEvent,  "hecks/domain_model/domain_event"
    autoload :Policy,       "hecks/domain_model/policy"
    autoload :Validation,   "hecks/domain_model/validation"
    autoload :Invariant,       "hecks/domain_model/invariant"
    autoload :Scope,           "hecks/domain_model/scope"
    autoload :Query,           "hecks/domain_model/query"
    autoload :PortDefinition,  "hecks/domain_model/port_definition"
    autoload :ReadModel,       "hecks/domain_model/read_model"
    autoload :ExternalSystem,  "hecks/domain_model/external_system"
    autoload :Actor,           "hecks/domain_model/actor"
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
    autoload :ContextAware,          "hecks/generators/context_aware"
    autoload :DomainGemGenerator,    "hecks/generators/domain_gem_generator"
    autoload :AggregateGenerator,   "hecks/generators/aggregate_generator"
    autoload :ValueObjectGenerator, "hecks/generators/value_object_generator"
    autoload :CommandGenerator,     "hecks/generators/command_generator"
    autoload :EventGenerator,       "hecks/generators/event_generator"
    autoload :PolicyGenerator,      "hecks/generators/policy_generator"
    autoload :PortGenerator,        "hecks/generators/port_generator"
    autoload :SpecGenerator,          "hecks/generators/spec_generator"
    autoload :SpecHelpers,            "hecks/generators/spec_helpers"
    autoload :AutoloadGenerator,      "hecks/generators/autoload_generator"
    autoload :MemoryAdapterGenerator,  "hecks/generators/memory_adapter_generator"
    autoload :SqlAdapterGenerator,     "hecks/generators/sql_adapter_generator"
    autoload :SqlBuilder,              "hecks/generators/sql_builder"
    autoload :SqlMigrationGenerator,   "hecks/generators/sql_migration_generator"
    autoload :QueryObjectGenerator,    "hecks/generators/query_object_generator"
    autoload :QueryGenerator,          "hecks/generators/query_generator"
  end

  module EventStorm
    autoload :Parser,        "hecks/event_storm/parser"
    autoload :YamlParser,    "hecks/event_storm/yaml_parser"
    autoload :DomainBuilder, "hecks/event_storm/domain_builder"
    autoload :DslGenerator,  "hecks/event_storm/dsl_generator"
    autoload :Result,        "hecks/event_storm/result"
  end

  module Services
    autoload :Application,       "hecks/services/application"
    autoload :AggregateWiring,   "hecks/services/aggregate_wiring"
    autoload :CommandBus,        "hecks/services/command_bus"
    autoload :CommandRunner,     "hecks/services/command_runner"
    autoload :EventBus,          "hecks/services/event_bus"
    autoload :CollectionProxy,   "hecks/services/collection_proxy"
    autoload :ContextProxy,      "hecks/services/context_proxy"
    autoload :CommandWiring,     "hecks/services/command_wiring"
    autoload :PortEnforcer,      "hecks/services/port_enforcer"
    autoload :QueryBuilder,      "hecks/services/query_builder"
    autoload :AdHocQueries,      "hecks/services/ad_hoc_queries"
    autoload :RepositoryMethods, "hecks/services/repository_methods"
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

    generator = Generators::DomainGemGenerator.new(domain, version: version, output_dir: output_dir)
    generator.generate
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
    Generators::AggregateGenerator.new(agg, domain_module: mod, context_module: ctx_mod).generate
  end

  require "active_hecks/railtie" if defined?(::Rails::Railtie)
end

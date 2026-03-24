# Hecks Autoloads
#
# Central autoload registry mapping every Hecks module to its source file.
# Infrastructure layer — required by lib/hecks.rb to enable lazy loading
# of all framework components (CLI, DSL, Generators, Services, HTTP, MCP, etc.).
#
module Hecks
  autoload :Command,        "hecks/command"
  autoload :Model,           "hecks/model"
  autoload :Query,           "hecks/query"
  autoload :Specification,   "hecks/specification"
  autoload :Utils,          "hecks/utils"
  autoload :VERSION,        "hecks/version"
  autoload :Configuration,  "hecks/configuration"
  autoload :CLI,            "hecks/cli"
  autoload :Session,        "hecks/session"
  autoload :Validator,      "hecks/validator"
  autoload :Versioner,      "hecks/versioner"
  autoload :Migrations,     "hecks/migrations"
  autoload :DomainGlossary,  "hecks/domain_glossary"
  autoload :DomainVisualizer, "hecks/domain_visualizer"
  autoload :DslSerializer,      "hecks/dsl_serializer"
  autoload :ConsoleRunner,      "hecks/console_runner"

  module ValidationRules
    autoload :BaseRule,    "hecks/validation_rules/base_rule"
    autoload :Naming,      "hecks/validation_rules/naming"
    autoload :References,  "hecks/validation_rules/references"
    autoload :Structure,   "hecks/validation_rules/structure"
  end

  module DomainModel
    autoload :Behavior,  "hecks/domain_model/behavior"
    autoload :Structure, "hecks/domain_model/structure"
  end

  module DSL
    autoload :AttributeCollector, "hecks/dsl/attribute_collector"
    autoload :DomainBuilder,      "hecks/dsl/domain_builder"
    autoload :AggregateBuilder,   "hecks/dsl/aggregate_builder"
    autoload :ValueObjectBuilder, "hecks/dsl/value_object_builder"
    autoload :EntityBuilder,      "hecks/dsl/entity_builder"
    autoload :CommandBuilder,     "hecks/dsl/command_builder"
    autoload :PolicyBuilder,      "hecks/dsl/policy_builder"
    autoload :AggregateRebuilder, "hecks/dsl/aggregate_rebuilder"
    autoload :PortBuilder,        "hecks/dsl/port_builder"
  end

  module Generators
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
    autoload :Runtime,           "hecks/services/runtime"
    autoload :Application,      "hecks/services/runtime"
    autoload :AggregateWiring,  "hecks/services/aggregate_wiring"
    autoload :EventBus,         "hecks/services/event_bus"
    autoload :PortEnforcer,     "hecks/services/port_enforcer"
    autoload :Persistence,      "hecks/services/persistence"
    autoload :Querying,         "hecks/services/querying"
    autoload :Commands,         "hecks/services/commands"
    autoload :Introspection,    "hecks/services/introspection"
  end

  module HTTP
    autoload :DomainServer,       "hecks/http/domain_server"
    autoload :RpcServer,          "hecks/http/rpc_server"
    autoload :RouteBuilder,       "hecks/http/route_builder"
    autoload :OpenapiGenerator,   "hecks/http/openapi_generator"
    autoload :RpcDiscovery,       "hecks/http/rpc_discovery"
    autoload :JsonSchemaGenerator, "hecks/http/json_schema_generator"
  end
end

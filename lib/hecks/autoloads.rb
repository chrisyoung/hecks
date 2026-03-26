# Hecks Autoloads
#
# Central autoload registry mapping every Hecks module to its source file.
# Infrastructure layer — required by lib/hecks.rb to enable lazy loading
# of all framework components. Connection autoloads (HTTP, MCP, SQL, CLI)
# live in their respective top-level entry points (hecks_serve, hecks_ai,
# hecks_persist, hecks_cli).
#
module Hecks
  # Mixins (included into generated classes)
  autoload :Command,        "hecks/mixins/command"
  autoload :Model,          "hecks/mixins/model"
  autoload :Query,          "hecks/mixins/query"
  autoload :Specification,  "hecks/mixins/specification"

  # Framework plumbing
  autoload :Utils,          "hecks/utils"
  autoload :VERSION,        "hecks/version"
  autoload :Configuration,  "hecks/runtime/configuration"
  autoload :CLI,            "hecks_cli/cli"
  autoload :Session,        "hecks/session"
  autoload :Versioner,      "hecks/domain/versioner"
  autoload :Migrations,     "hecks/domain/migrations"

  # Domain tools
  autoload :Validator,         "hecks/domain/validator"
  autoload :DomainConnections, "hecks/domain/connections"
  autoload :DomainGlossary,    "hecks/domain/glossary"
  autoload :DomainVisualizer,  "hecks/domain/visualizer"
  autoload :DslSerializer,     "hecks/domain/dsl_serializer"

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
    autoload :PolicyBuilder,       "hecks/dsl/policy_builder"
    autoload :AggregateRebuilder,  "hecks/dsl/aggregate_rebuilder"
    autoload :PortBuilder,         "hecks/dsl/port_builder"
    autoload :ServiceBuilder,      "hecks/dsl/service_builder"
    autoload :LifecycleBuilder,    "hecks/dsl/lifecycle_builder"
    autoload :ReadModelBuilder,    "hecks/dsl/read_model_builder"
    autoload :WorkflowBuilder,     "hecks/dsl/workflow_builder"
    autoload :BranchBuilder,       "hecks/dsl/workflow_builder"
    autoload :StepCollector,       "hecks/dsl/workflow_builder"
  end

  module Generators
    autoload :Domain,         "hecks/generators/domain"
    autoload :SQL,            "hecks_persist"
    autoload :Infrastructure, "hecks/generators/infrastructure"
  end

  module EventStorm
    autoload :Parser,        "hecks/event_storm/parser"
    autoload :YamlParser,    "hecks/event_storm/yaml_parser"
    autoload :DomainBuilder, "hecks/event_storm/domain_builder"
    autoload :DslGenerator,  "hecks/event_storm/dsl_generator"
    autoload :Result,        "hecks/event_storm/result"
  end

  autoload :Runtime,           "hecks/runtime"
  autoload :Application,       "hecks/runtime"
  # PortWiring is included directly in Runtime, no autoload needed
  autoload :AttachmentMethods, "hecks/runtime/attachment_methods"
  autoload :EventBus,          "hecks/ports/event_bus/event_bus"
  autoload :FilteredEventBus,  "hecks/ports/event_bus/filtered_event_bus"
  autoload :CrossDomainQuery,  "hecks/ports/queries/cross_domain_query"
  autoload :CrossDomainView,   "hecks/ports/event_bus/cross_domain_view"
  autoload :Queue,             "hecks/ports/queue"
  autoload :PortEnforcer,      "hecks/runtime/port_enforcer"
  autoload :Persistence,       "hecks/ports/repository"
  autoload :Querying,          "hecks/ports/queries"
  autoload :Commands,          "hecks/ports/commands"
  autoload :Introspection,     "hecks/runtime/introspection"
  autoload :Versioning,        "hecks/runtime/versioning"
  autoload :ViewBinding,       "hecks/runtime/view_binding"
  autoload :WorkflowExecutor,  "hecks/runtime/workflow_executor"

  module HTTP
    autoload :DomainServer,       "hecks/extensions/serve/domain_server"
    autoload :RpcServer,          "hecks/extensions/serve/rpc_server"
    autoload :RouteBuilder,       "hecks/extensions/serve/route_builder"
    autoload :OpenapiGenerator,   "hecks/generators/docs/openapi_generator"
    autoload :RpcDiscovery,       "hecks/generators/docs/rpc_discovery"
    autoload :JsonSchemaGenerator, "hecks/generators/docs/json_schema_generator"
  end
end

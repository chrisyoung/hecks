# Hecks::Generators::Domain
#
# Parent module for domain artifact generators. Autoloads generators for
# aggregates, value objects, commands, events, policies, query classes,
# and query object modules. Part of the Generators layer, consumed by
# DomainGemGenerator and SourceBuilder to produce domain code.
#
#   Domain::AggregateGenerator.new(agg, domain_module: "PizzasDomain").generate
#
module Hecks
  module Generators
    module Domain
      autoload :AggregateGenerator,    "hecks/generators/domain/aggregate_generator"
      autoload :ValueObjectGenerator,  "hecks/generators/domain/value_object_generator"
      autoload :EntityGenerator,       "hecks/generators/domain/entity_generator"
      autoload :CommandGenerator,      "hecks/generators/domain/command_generator"
      autoload :EventGenerator,        "hecks/generators/domain/event_generator"
      autoload :PolicyGenerator,       "hecks/generators/domain/policy_generator"
      autoload :QueryGenerator,        "hecks/generators/domain/query_generator"
      autoload :QueryObjectGenerator,  "hecks/generators/domain/query_object_generator"
      autoload :SubscriberGenerator,      "hecks/generators/domain/subscriber_generator"
      autoload :SpecificationGenerator,  "hecks/generators/domain/specification_generator"
    end
  end
end

# Hecks::Generators::Domain
#
# Domain artifact generators: aggregates, value objects, commands,
# events, policies, and query objects.
#
module Hecks
  module Generators
    module Domain
      autoload :AggregateGenerator,    "hecks/generators/domain/aggregate_generator"
      autoload :ValueObjectGenerator,  "hecks/generators/domain/value_object_generator"
      autoload :CommandGenerator,      "hecks/generators/domain/command_generator"
      autoload :EventGenerator,        "hecks/generators/domain/event_generator"
      autoload :PolicyGenerator,       "hecks/generators/domain/policy_generator"
      autoload :QueryGenerator,        "hecks/generators/domain/query_generator"
      autoload :QueryObjectGenerator,  "hecks/generators/domain/query_object_generator"
    end
  end
end

# Hecks::ValidationRules::Naming
#
# Rules that enforce naming conventions: command verb prefixes,
# no duplicate names, unique aggregate names.
#
module Hecks
  module ValidationRules
    module Naming
      autoload :CommandNaming,        "hecks/validation_rules/naming/command_naming"
      autoload :NameCollisions,       "hecks/validation_rules/naming/name_collisions"
      autoload :UniqueAggregateNames, "hecks/validation_rules/naming/unique_aggregate_names"
    end
  end
end

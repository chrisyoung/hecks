# Hecks::ValidationRules::Naming
#
# Naming convention rules: command verb prefixes, no duplicate names,
# unique aggregate names, and reserved name detection. Part of the
# ValidationRules layer -- autoloads individual rule classes.
#
module Hecks
  module ValidationRules
    module Naming
      autoload :CommandNaming,        "hecks/validation_rules/naming/command_naming"
      autoload :NameCollisions,       "hecks/validation_rules/naming/name_collisions"
      autoload :UniqueAggregateNames, "hecks/validation_rules/naming/unique_aggregate_names"
      autoload :ReservedNames,        "hecks/validation_rules/naming/reserved_names"
    end
  end
end

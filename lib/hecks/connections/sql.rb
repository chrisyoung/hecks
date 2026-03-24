# Hecks::Generators::SQL
#
# Parent module for SQL-specific generators: adapter classes, builder helpers,
# and migration scripts for database persistence. Part of the Generators layer,
# consumed by DomainGemGenerator and the CLI `hecks domain build` command.
#
module Hecks
  module Generators
    module SQL
      autoload :SqlAdapterGenerator,   "hecks/connections/sql/sql_adapter_generator"
      autoload :SqlBuilder,            "hecks/connections/sql/sql_builder"
      autoload :SqlMigrationGenerator, "hecks/connections/sql/sql_migration_generator"
    end
  end
end

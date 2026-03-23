# Hecks::Generators::SQL
#
# SQL-specific generators: adapter classes, builder helpers, and
# migration scripts for database persistence.
#
module Hecks
  module Generators
    module SQL
      autoload :SqlAdapterGenerator,   "hecks/generators/sql/sql_adapter_generator"
      autoload :SqlBuilder,            "hecks/generators/sql/sql_builder"
      autoload :SqlMigrationGenerator, "hecks/generators/sql/sql_migration_generator"
    end
  end
end

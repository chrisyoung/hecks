# HecksPersist
#
# SQL persistence connection for Hecks domains. Generates Sequel-based
# repository adapters, SQL schema, and migration files. Supports SQLite,
# Postgres, and MySQL via Sequel.
#
# Future gem: hecks_persist
#
#   require "hecks_persist"
#   app = Hecks.boot(__dir__, adapter: :sqlite)
#
module Hecks
  module Generators
    module SQL
      autoload :SqlAdapterGenerator,   "hecks_persist/sql_adapter_generator"
      autoload :SqlBuilder,            "hecks_persist/sql_builder"
      autoload :SqlMigrationGenerator, "hecks_persist/sql_migration_generator"
    end
  end

  module Migrations
    module Strategies
      autoload :SqlStrategy, "hecks_persist/sql_strategy"
    end
  end
end

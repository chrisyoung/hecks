# Hecks::Migrations
#
# Schema migration infrastructure: diff detection, snapshot tracking,
# strategy dispatch, and migration execution.
#
module Hecks
  module Migrations
    autoload :DomainDiff,       "hecks/migrations/domain_diff"
    autoload :DomainSnapshot,   "hecks/migrations/domain_snapshot"
    autoload :MigrationStrategy, "hecks/migrations/migration_strategy"
    autoload :MigrationRunner,  "hecks/migrations/migration_runner"

    module Strategies
      autoload :SqlStrategy, "hecks/migration_strategies/sql_strategy"
    end
  end
end

# Hecks::Migrations
#
# Schema migration infrastructure: diff detection, snapshot tracking,
# strategy dispatch, and migration execution. Parent module that
# autoloads DomainDiff, DomainSnapshot, MigrationStrategy, and
# MigrationRunner plus the Strategies namespace.
#
#   changes = Migrations::DomainDiff.call(old_domain, new_domain)
#   Migrations::MigrationStrategy.run_all(changes)
#
module Hecks
  module Migrations
    autoload :DomainDiff,       "hecks/migrations/domain_diff"
    autoload :DomainSnapshot,   "hecks/migrations/domain_snapshot"
    autoload :MigrationStrategy, "hecks/migrations/migration_strategy"
    autoload :MigrationRunner,  "hecks/migrations/migration_runner"

    module Strategies
      autoload :SqlStrategy, "hecks/connections/sql/sql_strategy"
    end
  end
end

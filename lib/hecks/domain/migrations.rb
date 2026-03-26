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
    autoload :DomainDiff,       "hecks/domain/migrations/domain_diff"
    autoload :DomainSnapshot,   "hecks/domain/migrations/domain_snapshot"
    autoload :MigrationStrategy, "hecks/domain/migrations/migration_strategy"
    autoload :MigrationRunner,  "hecks/domain/migrations/migration_runner"

    module Strategies
      autoload :SqlStrategy, "hecks_persist/sql_strategy"
    end
  end
end

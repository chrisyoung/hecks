# HecksPersist

The persistence layer — Sequel-based SQL adapters for domain repositories.

Generates SQL repository adapters, migration files, and schema definitions. Owns all database-specific extensions.

## Sub-areas

- **hecks_persist/** — SqlStrategy, SqlBuilder, SqlBoot, SqlSetup, SqlHelpers, SqlAdapterGenerator, SqlMigrationGenerator, DatabaseConnection
- **extensions/** — SQLite, PostgreSQL, MySQL, CQRS (read/write split), Transactions

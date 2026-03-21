# Hecks::MigrationRunner
#
# Executes pending SQL migration files from db/hecks_migrate/ against a
# database connection. Tracks applied migrations in a hecks_schema_migrations
# table to avoid re-running them.
#
# The connection is duck-typed — any object responding to #execute(sql).
# In Rails, pass ActiveRecord::Base.connection. For SQLite, wrap the db.
#
#   runner = MigrationRunner.new(connection: ActiveRecord::Base.connection)
#   runner.pending   # => ["20260321120000_hecks_migration.sql"]
#   runner.run_all   # applies pending migrations
#
module Hecks
  class MigrationRunner
    TRACKING_TABLE = "hecks_schema_migrations"

    def initialize(connection:, migration_dir: "db/hecks_migrate")
      @connection = connection
      @migration_dir = migration_dir
      setup_tracking_table
    end

    def pending
      applied = applied_versions
      all_migrations.reject { |f| applied.include?(File.basename(f)) }
    end

    def run_all
      results = []
      pending.each do |file|
        sql = File.read(file)
        sql.split(";").each do |stmt|
          stmt = stmt.strip
          @connection.execute(stmt + ";") unless stmt.empty?
        end
        record_migration(File.basename(file))
        results << File.basename(file)
      end
      results
    end

    private

    def setup_tracking_table
      @connection.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS #{TRACKING_TABLE} (
          version VARCHAR(255) PRIMARY KEY
        );
      SQL
    end

    def applied_versions
      rows = @connection.execute("SELECT version FROM #{TRACKING_TABLE};")
      rows.map { |r| r.is_a?(Hash) ? r["version"] : r[0] }
    end

    def record_migration(filename)
      @connection.execute(
        "INSERT INTO #{TRACKING_TABLE} (version) VALUES ('#{filename}');"
      )
    end

    def all_migrations
      return [] unless Dir.exist?(@migration_dir)

      Dir.glob(File.join(@migration_dir, "*.sql")).sort
    end
  end
end

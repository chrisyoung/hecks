require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::MigrationRunner do
  let(:tmpdir) { Dir.mktmpdir }
  let(:migration_dir) { File.join(tmpdir, "db/hecks_migrate") }
  let(:db) { FakeConnection.new }
  let(:runner) { described_class.new(connection: db, migration_dir: migration_dir) }

  # A simple in-memory connection that tracks executed SQL
  class FakeConnection
    attr_reader :executed

    def initialize
      @executed = []
      @tables = {}
      # Pre-create the tracking table (setup_tracking_table will issue CREATE IF NOT EXISTS)
      @tables["hecks_schema_migrations"] = []
    end

    def execute(sql)
      @executed << sql
      if sql.strip.start_with?("CREATE TABLE IF NOT EXISTS hecks_schema_migrations")
        @tables["hecks_schema_migrations"] ||= []
      elsif sql.strip.start_with?("SELECT version FROM hecks_schema_migrations")
        return @tables["hecks_schema_migrations"].map { |v| { "version" => v } }
      elsif sql.strip.start_with?("INSERT INTO hecks_schema_migrations")
        version = sql.match(/'([^']+)'/)[1]
        @tables["hecks_schema_migrations"] << version
      end
      []
    end
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#pending" do
    it "returns empty when no migration files exist" do
      expect(runner.pending).to be_empty
    end

    it "returns all migration files when none applied" do
      FileUtils.mkdir_p(migration_dir)
      File.write(File.join(migration_dir, "20260321120000_hecks_migration.sql"), "CREATE TABLE pizzas;")

      expect(runner.pending.size).to eq(1)
    end

    it "excludes already applied migrations" do
      FileUtils.mkdir_p(migration_dir)
      File.write(File.join(migration_dir, "20260321120000_hecks_migration.sql"), "CREATE TABLE pizzas;")

      runner.run_all  # apply it

      new_runner = described_class.new(connection: db, migration_dir: migration_dir)
      expect(new_runner.pending).to be_empty
    end
  end

  describe "#run_all" do
    it "returns empty when nothing is pending" do
      expect(runner.run_all).to be_empty
    end

    it "executes SQL statements from migration files" do
      FileUtils.mkdir_p(migration_dir)
      File.write(
        File.join(migration_dir, "20260321120000_hecks_migration.sql"),
        "CREATE TABLE pizzas (\n  id VARCHAR(36) PRIMARY KEY\n);"
      )

      applied = runner.run_all
      expect(applied).to eq(["20260321120000_hecks_migration.sql"])
      expect(db.executed.any? { |s| s.include?("CREATE TABLE pizzas") }).to be true
    end

    it "records applied migrations in tracking table" do
      FileUtils.mkdir_p(migration_dir)
      File.write(File.join(migration_dir, "20260321120000_hecks_migration.sql"), "SELECT 1;")

      runner.run_all
      expect(db.executed.any? { |s| s.include?("INSERT INTO hecks_schema_migrations") }).to be true
    end

    it "applies migrations in sorted order" do
      FileUtils.mkdir_p(migration_dir)
      File.write(File.join(migration_dir, "20260322_second.sql"), "SELECT 2;")
      File.write(File.join(migration_dir, "20260321_first.sql"), "SELECT 1;")

      applied = runner.run_all
      expect(applied).to eq(["20260321_first.sql", "20260322_second.sql"])
    end
  end
end

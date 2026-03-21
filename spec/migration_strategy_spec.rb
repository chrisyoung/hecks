require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::MigrationStrategy do
  after { described_class.registry.delete(:test) }

  describe ".register" do
    it "registers a strategy" do
      strategy_class = Class.new(described_class) do
        def generate(changes) = "test migration"
        def file_path = "db/test.sql"
      end

      described_class.register(:test, strategy_class)
      expect(described_class.for(:test)).to eq(strategy_class)
    end
  end

  describe ".run_all" do
    it "runs all registered strategies" do
      tmpdir = Dir.mktmpdir
      strategy_class = Class.new(described_class) do
        def generate(changes) = "-- migration"
        def file_path = "test_migration.sql"
      end

      described_class.register(:test, strategy_class)
      changes = [Hecks::DomainDiff::Change.new(kind: :add_attribute, aggregate: "Pizza", details: { name: :size })]

      files = described_class.run_all(changes, output_dir: tmpdir)
      expect(files.size).to eq(1)
      expect(File.read(files.first)).to eq("-- migration")

      FileUtils.rm_rf(tmpdir)
    end

    it "skips strategies that return nil" do
      strategy_class = Class.new(described_class) do
        def generate(changes) = nil
        def file_path = "noop.sql"
      end

      described_class.register(:test, strategy_class)
      files = described_class.run_all([Hecks::DomainDiff::Change.new(kind: :add_attribute, aggregate: "X", details: {})])
      expect(files).to be_empty
    end

    it "returns empty for no changes" do
      files = described_class.run_all([])
      expect(files).to be_empty
    end
  end
end

RSpec.describe Hecks::MigrationStrategies::SqlStrategy do
  subject(:strategy) { described_class.new(output_dir: tmpdir) }
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#generate" do
    it "generates ADD COLUMN for added attributes" do
      changes = [
        Hecks::DomainDiff::Change.new(
          kind: :add_attribute,
          aggregate: "Pizza",
          details: { name: :size, type: String, list: false, reference: false }
        )
      ]

      result = strategy.generate(changes)
      expect(result).to include("ALTER TABLE pizzas ADD COLUMN size VARCHAR(255)")
    end

    it "generates DROP COLUMN for removed attributes" do
      changes = [
        Hecks::DomainDiff::Change.new(
          kind: :remove_attribute,
          aggregate: "Pizza",
          details: { name: :temp }
        )
      ]

      result = strategy.generate(changes)
      expect(result).to include("ALTER TABLE pizzas DROP COLUMN temp")
    end

    it "generates CREATE TABLE for new aggregates" do
      attr = Hecks::DomainModel::Attribute.new(name: :name, type: String)
      changes = [
        Hecks::DomainDiff::Change.new(
          kind: :add_aggregate,
          aggregate: "Review",
          details: { attributes: [attr], value_objects: [] }
        )
      ]

      result = strategy.generate(changes)
      expect(result).to include("CREATE TABLE reviews")
      expect(result).to include("name VARCHAR(255)")
    end

    it "generates DROP TABLE for removed aggregates" do
      changes = [
        Hecks::DomainDiff::Change.new(
          kind: :remove_aggregate,
          aggregate: "Review",
          details: {}
        )
      ]

      result = strategy.generate(changes)
      expect(result).to include("DROP TABLE IF EXISTS reviews")
    end

    it "returns nil for no changes" do
      expect(strategy.generate([])).to be_nil
    end
  end

  describe "#write" do
    it "writes the migration file" do
      path = strategy.write("ALTER TABLE pizzas ADD COLUMN size VARCHAR(255);")
      expect(File.exist?(path)).to be true
      expect(path).to include("db/migrate/")
      expect(path).to end_with("_hecks_migration.sql")
    end
  end
end

require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::DomainSnapshot do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  let(:tmpdir) { Dir.mktmpdir }
  let(:snapshot_path) { File.join(tmpdir, ".hecks_domain_snapshot.rb") }

  after { FileUtils.rm_rf(tmpdir) }

  describe ".save" do
    it "writes a DSL snapshot file" do
      described_class.save(domain, path: snapshot_path)

      expect(File.exist?(snapshot_path)).to be true
      content = File.read(snapshot_path)
      expect(content).to include('Hecks.domain "Pizzas"')
      expect(content).to include("attribute :name, String")
    end

    it "returns the path" do
      result = described_class.save(domain, path: snapshot_path)
      expect(result).to eq(snapshot_path)
    end
  end

  describe ".load" do
    it "returns nil when no snapshot exists" do
      result = described_class.load(path: snapshot_path)
      expect(result).to be_nil
    end

    it "round-trips a domain through save/load" do
      described_class.save(domain, path: snapshot_path)
      loaded = described_class.load(path: snapshot_path)

      expect(loaded.name).to eq("Pizzas")
      expect(loaded.aggregates.size).to eq(1)
      expect(loaded.aggregates.first.name).to eq("Pizza")
      expect(loaded.aggregates.first.attributes.map(&:name)).to include(:name, :description)
    end
  end

  describe ".exists?" do
    it "returns false when no snapshot exists" do
      expect(described_class.exists?(path: snapshot_path)).to be false
    end

    it "returns true after saving" do
      described_class.save(domain, path: snapshot_path)
      expect(described_class.exists?(path: snapshot_path)).to be true
    end
  end
end

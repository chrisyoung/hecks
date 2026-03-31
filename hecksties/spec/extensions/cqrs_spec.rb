require "spec_helper"
require "hecks/extensions/cqrs"

RSpec.describe HecksCqrs do
  let(:mod) do
    m = Module.new
    m.extend(Hecks::DomainConnections)
    m
  end

  describe ".active?" do
    it "returns false when no connections configured" do
      expect(HecksCqrs.active?(mod)).to be false
    end

    it "returns false with a single unnamed connection" do
      mod.extend(:sqlite)
      expect(HecksCqrs.active?(mod)).to be false
    end

    it "returns true with multiple named connections" do
      mod.extend(:sqlite, as: :write)
      mod.extend(:sqlite, as: :read, database: "read.db")
      expect(HecksCqrs.active?(mod)).to be true
    end
  end

  describe ".connection_for" do
    it "returns nil when no connections configured" do
      expect(HecksCqrs.connection_for(mod, :write)).to be_nil
    end

    it "returns config for a named connection" do
      mod.extend(:sqlite, as: :write)
      expect(HecksCqrs.connection_for(mod, :write).type).to eq(:sqlite)
    end

    it "returns config for :default unnamed connection" do
      mod.extend(:sqlite)
      expect(HecksCqrs.connection_for(mod, :default).type).to eq(:sqlite)
    end

    it "returns nil for unknown connection name" do
      mod.extend(:sqlite, as: :write)
      expect(HecksCqrs.connection_for(mod, :read)).to be_nil
    end
  end
end

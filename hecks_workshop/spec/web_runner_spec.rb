require "spec_helper"

RSpec.describe Hecks::Workshop::WebRunner do
  before { allow($stdout).to receive(:puts) }

  describe "#initialize" do
    it "creates a workshop" do
      runner = described_class.new(name: "TestDomain")
      expect(runner.workshop).to be_a(Hecks::Workshop)
      expect(runner.workshop.name).to eq("TestDomain")
    end
  end
end

RSpec.describe Hecks::Workshop::WebRunner::StateSerializer do
  let(:workshop) { Hecks::Workshop.new("TestDomain") }
  let(:serializer) { described_class.new(workshop) }

  before { allow($stdout).to receive(:puts) }

  describe "#serialize" do
    it "returns sketch mode with empty aggregates" do
      state = serializer.serialize
      expect(state[:mode]).to eq("sketch")
      expect(state[:domain_name]).to eq("TestDomain")
      expect(state[:aggregates]).to eq([])
      expect(state[:events]).to eq([])
    end

    it "includes aggregates after defining them" do
      workshop.aggregate("Pizza") { attribute :name, String }
      state = serializer.serialize
      expect(state[:aggregates].size).to eq(1)
      expect(state[:aggregates].first[:name]).to eq("Pizza")
      expect(state[:aggregates].first[:attributes].first[:name]).to eq(:name)
    end

    it "includes commands and events" do
      workshop.aggregate("Pizza") do
        attribute :name, String
        command :create
      end
      state = serializer.serialize
      agg = state[:aggregates].first
      expect(agg[:commands]).to include("create")
      expect(agg[:events]).to include("created")
    end
  end
end

require "spec_helper"

RSpec.describe ComplianceDomain::RegulatoryFramework::Commands::RegisterFramework do
  describe "attributes" do
    subject(:command) { described_class.new(
          name: "example",
          jurisdiction: "example",
          version: "example",
          authority: "example"
        ) }

    it "has name" do
      expect(command.name).to eq("example")
    end

    it "has jurisdiction" do
      expect(command.jurisdiction).to eq("example")
    end

    it "has version" do
      expect(command.version).to eq("example")
    end

    it "has authority" do
      expect(command.authority).to eq("example")
    end

  end

  describe "event" do
    it "emits RegisteredFramework" do
      expect(described_class.event_name).to eq("RegisteredFramework")
    end
  end
end

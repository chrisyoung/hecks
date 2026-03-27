require "spec_helper"

RSpec.describe ModelRegistryDomain::AiModel::Commands::RegisterModel do
  describe "attributes" do
    subject(:command) { described_class.new(
          name: "example",
          version: "example",
          provider_id: "example",
          description: "example"
        ) }

    it "has name" do
      expect(command.name).to eq("example")
    end

    it "has version" do
      expect(command.version).to eq("example")
    end

    it "has provider_id" do
      expect(command.provider_id).to eq("example")
    end

    it "has description" do
      expect(command.description).to eq("example")
    end

  end

  describe "event" do
    it "emits RegisteredModel" do
      expect(described_class.event_name).to eq("RegisteredModel")
    end
  end
end

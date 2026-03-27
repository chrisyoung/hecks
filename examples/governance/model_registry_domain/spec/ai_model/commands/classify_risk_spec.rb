require "spec_helper"

RSpec.describe ModelRegistryDomain::AiModel::Commands::ClassifyRisk do
  describe "attributes" do
    subject(:command) { described_class.new(model_id: "example", risk_level: "example") }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

    it "has risk_level" do
      expect(command.risk_level).to eq("example")
    end

  end

  describe "event" do
    it "emits ClassifiedRisk" do
      expect(described_class.event_name).to eq("ClassifiedRisk")
    end
  end
end

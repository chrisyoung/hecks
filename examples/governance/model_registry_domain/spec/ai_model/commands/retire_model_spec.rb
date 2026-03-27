require "spec_helper"

RSpec.describe ModelRegistryDomain::AiModel::Commands::RetireModel do
  describe "attributes" do
    subject(:command) { described_class.new(model_id: "example") }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

  end

  describe "event" do
    it "emits RetiredModel" do
      expect(described_class.event_name).to eq("RetiredModel")
    end
  end
end

require "spec_helper"

RSpec.describe ComplianceDomain::Exemption::Commands::RequestExemption do
  describe "attributes" do
    subject(:command) { described_class.new(
          model_id: "example",
          policy_id: "example",
          requirement: "example",
          reason: "example"
        ) }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

    it "has policy_id" do
      expect(command.policy_id).to eq("example")
    end

    it "has requirement" do
      expect(command.requirement).to eq("example")
    end

    it "has reason" do
      expect(command.reason).to eq("example")
    end

  end

  describe "event" do
    it "emits RequestedExemption" do
      expect(described_class.event_name).to eq("RequestedExemption")
    end
  end
end

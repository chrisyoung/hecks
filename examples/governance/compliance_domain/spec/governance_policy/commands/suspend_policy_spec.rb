require "spec_helper"

RSpec.describe ComplianceDomain::GovernancePolicy::Commands::SuspendPolicy do
  describe "attributes" do
    subject(:command) { described_class.new(policy_id: "example") }

    it "has policy_id" do
      expect(command.policy_id).to eq("example")
    end

  end

  describe "event" do
    it "emits SuspendedPolicy" do
      expect(described_class.event_name).to eq("SuspendedPolicy")
    end
  end
end

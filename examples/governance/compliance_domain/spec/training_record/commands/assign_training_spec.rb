require "spec_helper"

RSpec.describe ComplianceDomain::TrainingRecord::Commands::AssignTraining do
  describe "attributes" do
    subject(:command) { described_class.new(stakeholder_id: "example", policy_id: "example") }

    it "has stakeholder_id" do
      expect(command.stakeholder_id).to eq("example")
    end

    it "has policy_id" do
      expect(command.policy_id).to eq("example")
    end

  end

  describe "event" do
    it "emits AssignedTraining" do
      expect(described_class.event_name).to eq("AssignedTraining")
    end
  end
end

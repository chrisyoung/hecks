require "spec_helper"

RSpec.describe ComplianceDomain::ComplianceReview::Commands::OpenReview do
  describe "attributes" do
    subject(:command) { described_class.new(
          model_id: "example",
          policy_id: "example",
          reviewer_id: "example"
        ) }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

    it "has policy_id" do
      expect(command.policy_id).to eq("example")
    end

    it "has reviewer_id" do
      expect(command.reviewer_id).to eq("example")
    end

  end

  describe "event" do
    it "emits OpenedReview" do
      expect(described_class.event_name).to eq("OpenedReview")
    end
  end
end

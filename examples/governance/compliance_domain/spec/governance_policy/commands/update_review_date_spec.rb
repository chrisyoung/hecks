require "spec_helper"

RSpec.describe ComplianceDomain::GovernancePolicy::Commands::UpdateReviewDate do
  describe "attributes" do
    subject(:command) { described_class.new(policy_id: "example", review_date: Date.today) }

    it "has policy_id" do
      expect(command.policy_id).to eq("example")
    end

    it "has review_date" do
      expect(command.review_date).to eq(Date.today)
    end

  end

  describe "event" do
    it "emits UpdatedReviewDate" do
      expect(described_class.event_name).to eq("UpdatedReviewDate")
    end
  end
end

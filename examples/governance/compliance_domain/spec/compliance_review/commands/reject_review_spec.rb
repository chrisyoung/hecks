require "spec_helper"

RSpec.describe ComplianceDomain::ComplianceReview::Commands::RejectReview do
  describe "attributes" do
    subject(:command) { described_class.new(review_id: "example", notes: "example") }

    it "has review_id" do
      expect(command.review_id).to eq("example")
    end

    it "has notes" do
      expect(command.notes).to eq("example")
    end

  end

  describe "event" do
    it "emits RejectedReview" do
      expect(described_class.event_name).to eq("RejectedReview")
    end
  end
end

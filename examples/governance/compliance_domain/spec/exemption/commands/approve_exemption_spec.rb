require "spec_helper"

RSpec.describe ComplianceDomain::Exemption::Commands::ApproveExemption do
  describe "attributes" do
    subject(:command) { described_class.new(
          exemption_id: "example",
          approved_by_id: "example",
          expires_at: Date.today
        ) }

    it "has exemption_id" do
      expect(command.exemption_id).to eq("example")
    end

    it "has approved_by_id" do
      expect(command.approved_by_id).to eq("example")
    end

    it "has expires_at" do
      expect(command.expires_at).to eq(Date.today)
    end

  end

  describe "event" do
    it "emits ApprovedExemption" do
      expect(described_class.event_name).to eq("ApprovedExemption")
    end
  end
end

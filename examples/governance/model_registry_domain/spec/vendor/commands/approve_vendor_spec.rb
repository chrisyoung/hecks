require "spec_helper"

RSpec.describe ModelRegistryDomain::Vendor::Commands::ApproveVendor do
  describe "attributes" do
    subject(:command) { described_class.new(
          vendor_id: "example",
          assessment_date: Date.today,
          next_review_date: Date.today
        ) }

    it "has vendor_id" do
      expect(command.vendor_id).to eq("example")
    end

    it "has assessment_date" do
      expect(command.assessment_date).to eq(Date.today)
    end

    it "has next_review_date" do
      expect(command.next_review_date).to eq(Date.today)
    end

  end

  describe "event" do
    it "emits ApprovedVendor" do
      expect(described_class.event_name).to eq("ApprovedVendor")
    end
  end
end

require "spec_helper"

RSpec.describe ModelRegistryDomain::Vendor::Commands::SuspendVendor do
  describe "attributes" do
    subject(:command) { described_class.new(vendor_id: "example") }

    it "has vendor_id" do
      expect(command.vendor_id).to eq("example")
    end

  end

  describe "event" do
    it "emits SuspendedVendor" do
      expect(described_class.event_name).to eq("SuspendedVendor")
    end
  end
end

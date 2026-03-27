require "spec_helper"

RSpec.describe ModelRegistryDomain::Vendor::Commands::RegisterVendor do
  describe "attributes" do
    subject(:command) { described_class.new(
          name: "example",
          contact_email: "example",
          risk_tier: "example"
        ) }

    it "has name" do
      expect(command.name).to eq("example")
    end

    it "has contact_email" do
      expect(command.contact_email).to eq("example")
    end

    it "has risk_tier" do
      expect(command.risk_tier).to eq("example")
    end

  end

  describe "event" do
    it "emits RegisteredVendor" do
      expect(described_class.event_name).to eq("RegisteredVendor")
    end
  end
end

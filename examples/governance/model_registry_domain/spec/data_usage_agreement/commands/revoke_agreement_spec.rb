require "spec_helper"

RSpec.describe ModelRegistryDomain::DataUsageAgreement::Commands::RevokeAgreement do
  describe "attributes" do
    subject(:command) { described_class.new(agreement_id: "example") }

    it "has agreement_id" do
      expect(command.agreement_id).to eq("example")
    end

  end

  describe "event" do
    it "emits RevokedAgreement" do
      expect(described_class.event_name).to eq("RevokedAgreement")
    end
  end
end

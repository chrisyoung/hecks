require "spec_helper"

RSpec.describe ComplianceDomain::Exemption::Commands::RevokeExemption do
  describe "attributes" do
    subject(:command) { described_class.new(exemption_id: "example") }

    it "has exemption_id" do
      expect(command.exemption_id).to eq("example")
    end

  end

  describe "event" do
    it "emits RevokedExemption" do
      expect(described_class.event_name).to eq("RevokedExemption")
    end
  end
end

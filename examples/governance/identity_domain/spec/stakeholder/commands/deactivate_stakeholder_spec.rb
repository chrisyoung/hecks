require "spec_helper"

RSpec.describe IdentityDomain::Stakeholder::Commands::DeactivateStakeholder do
  describe "attributes" do
    subject(:command) { described_class.new(stakeholder_id: "example") }

    it "has stakeholder_id" do
      expect(command.stakeholder_id).to eq("example")
    end

  end

  describe "event" do
    it "emits DeactivatedStakeholder" do
      expect(described_class.event_name).to eq("DeactivatedStakeholder")
    end
  end
end

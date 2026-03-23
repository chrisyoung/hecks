require "spec_helper"

RSpec.describe ShippingDomain::Shipment::Commands::ShipShipment do
  subject(:command) do
    described_class.new(shipment_id: "example")
  end

  describe "#initialize" do
    it "creates a frozen command" do
      expect(command).to be_frozen
    end

    it "has shipment_id" do
      expect(command.shipment_id).not_to be_nil
    end
  end
end

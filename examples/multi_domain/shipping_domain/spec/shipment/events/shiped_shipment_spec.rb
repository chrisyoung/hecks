require "spec_helper"

RSpec.describe ShippingDomain::Shipment::Events::ShipedShipment do
  subject(:event) do
    described_class.new(shipment_id: "example")
  end

  describe "#initialize" do
    it "creates a frozen event" do
      expect(event).to be_frozen
    end

    it "records occurred_at" do
      expect(event.occurred_at).to be_a(Time)
    end
  end
end

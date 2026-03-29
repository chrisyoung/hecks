require "spec_helper"

RSpec.describe ShippingDomain::Shipment::Commands::ShipShipment do
  describe "attributes" do
    subject(:command) { described_class.new(shipment_id: "example") }

    it "has shipment_id" do
      expect(command.shipment_id).to eq("example")
    end

  end

  describe "event" do
    it "emits ShippedShipment" do
      expect(described_class.event_name).to eq("ShippedShipment")
    end
  end

  describe "execution" do
    before { @app = Hecks.load(domain, force: true) }

    it "updates the aggregate and emits ShippedShipment" do
      agg = Shipment.create(pizza_id: "example", quantity: 1)
      Shipment.ship(shipment_id: "example")
      event_names = @app.events.map { |e| e.class.name.split("::").last }
      expect(event_names).to include("ShippedShipment")
    end
  end
end

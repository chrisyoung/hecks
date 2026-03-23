require "spec_helper"

RSpec.describe ShippingDomain::Shipment do
  subject(:shipment) do
    described_class.new(pizza_id: "example", quantity: 1, status: "example")
  end

  describe "#initialize" do
    it "creates a Shipment with an id" do
      expect(shipment.id).not_to be_nil
    end

    it "has pizza_id" do
      expect(shipment.pizza_id).not_to be_nil
    end

    it "has quantity" do
      expect(shipment.quantity).not_to be_nil
    end

    it "has status" do
      expect(shipment.status).not_to be_nil
    end
  end


describe "equality" do
  it "is equal to another Shipment with the same id" do
    id = SecureRandom.uuid
    a = described_class.new(pizza_id: "example", quantity: 1, status: "example", id: id)
    b = described_class.new(pizza_id: "example", quantity: 1, status: "example", id: id)
    expect(a).to eq(b)
  end
end
end

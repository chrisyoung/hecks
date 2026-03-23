require "spec_helper"

RSpec.describe PizzasDomain::Order do
  subject(:order) do
    described_class.new(pizza_id: "ref-id-123", quantity: 1)
  end

  describe "#initialize" do
    it "creates a Order with an id" do
      expect(order.id).not_to be_nil
    end

    it "has pizza_id" do
      expect(order.pizza_id).not_to be_nil
    end

    it "has quantity" do
      expect(order.quantity).not_to be_nil
    end
  end


describe "equality" do
  it "is equal to another Order with the same id" do
    id = SecureRandom.uuid
    a = described_class.new(pizza_id: "ref-id-123", quantity: 1, id: id)
    b = described_class.new(pizza_id: "ref-id-123", quantity: 1, id: id)
    expect(a).to eq(b)
  end
end
end

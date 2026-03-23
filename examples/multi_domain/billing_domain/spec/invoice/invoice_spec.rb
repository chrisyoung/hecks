require "spec_helper"

RSpec.describe BillingDomain::Invoice do
  subject(:invoice) do
    described_class.new(pizza_id: "example", quantity: 1, status: "example")
  end

  describe "#initialize" do
    it "creates a Invoice with an id" do
      expect(invoice.id).not_to be_nil
    end

    it "has pizza_id" do
      expect(invoice.pizza_id).not_to be_nil
    end

    it "has quantity" do
      expect(invoice.quantity).not_to be_nil
    end

    it "has status" do
      expect(invoice.status).not_to be_nil
    end
  end


describe "equality" do
  it "is equal to another Invoice with the same id" do
    id = SecureRandom.uuid
    a = described_class.new(pizza_id: "example", quantity: 1, status: "example", id: id)
    b = described_class.new(pizza_id: "example", quantity: 1, status: "example", id: id)
    expect(a).to eq(b)
  end
end
end

require "spec_helper"

RSpec.describe BillingDomain::Invoice do
  describe "creating a Invoice" do
    subject(:invoice) { described_class.new(
          pizza_id: "example",
          quantity: 1,
          status: "example"
        ) }

    it "assigns an id" do
      expect(invoice.id).not_to be_nil
    end

    it "sets pizza_id" do
      expect(invoice.pizza_id).to eq("example")
    end

    it "sets quantity" do
      expect(invoice.quantity).to eq(1)
    end

    it "sets status" do
      expect(invoice.status).to eq("example")
    end
  end

  describe "identity" do
    it "two Invoices with the same id are equal" do
      id = SecureRandom.uuid
      a = described_class.new(
          pizza_id: "example",
          quantity: 1,
          status: "example",
          id: id
        )
      b = described_class.new(
          pizza_id: "example",
          quantity: 1,
          status: "example",
          id: id
        )
      expect(a).to eq(b)
    end

    it "two Invoices with different ids are not equal" do
      a = described_class.new(
          pizza_id: "example",
          quantity: 1,
          status: "example"
        )
      b = described_class.new(
          pizza_id: "example",
          quantity: 1,
          status: "example"
        )
      expect(a).not_to eq(b)
    end
  end
end

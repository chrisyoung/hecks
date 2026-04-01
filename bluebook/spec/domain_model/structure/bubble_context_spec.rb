require "spec_helper"

RSpec.describe Hecks::DomainModel::Structure::BubbleContext do
  describe "#initialize" do
    it "stores name and aggregate names" do
      ctx = described_class.new(name: "Fulfillment", aggregate_names: ["Order", "Shipment"])
      expect(ctx.name).to eq("Fulfillment")
      expect(ctx.aggregate_names).to eq(["Order", "Shipment"])
    end

    it "stores an optional description" do
      ctx = described_class.new(name: "Billing", description: "Handles payments")
      expect(ctx.description).to eq("Handles payments")
    end

    it "defaults aggregate_names to empty array" do
      ctx = described_class.new(name: "Empty")
      expect(ctx.aggregate_names).to eq([])
    end

    it "defaults description to nil" do
      ctx = described_class.new(name: "Empty")
      expect(ctx.description).to be_nil
    end
  end
end

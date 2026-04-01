require "spec_helper"

RSpec.describe Hecks::DSL::BubbleContextBuilder do
  describe "#build" do
    it "builds a BubbleContext with aggregates and description" do
      builder = described_class.new("Fulfillment")
      builder.aggregate "Order"
      builder.aggregate "Shipment"
      builder.description "Handles fulfillment"

      ctx = builder.build
      expect(ctx).to be_a(Hecks::DomainModel::Structure::BubbleContext)
      expect(ctx.name).to eq("Fulfillment")
      expect(ctx.aggregate_names).to eq(["Order", "Shipment"])
      expect(ctx.description).to eq("Handles fulfillment")
    end

    it "builds an empty context without block calls" do
      ctx = described_class.new("Empty").build
      expect(ctx.aggregate_names).to eq([])
      expect(ctx.description).to be_nil
    end
  end
end

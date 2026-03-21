require "spec_helper"

RSpec.describe Hecks::DomainModel::Command do
  subject(:command) do
    described_class.new(name: "CreatePizza", attributes: [])
  end

  describe "#inferred_event_name" do
    it "converts Create to Created" do
      cmd = described_class.new(name: "CreatePizza", attributes: [])
      expect(cmd.inferred_event_name).to eq("CreatedPizza")
    end

    it "converts Add to Added" do
      cmd = described_class.new(name: "AddTopping", attributes: [])
      expect(cmd.inferred_event_name).to eq("AddedTopping")
    end

    it "converts Place to Placed" do
      cmd = described_class.new(name: "PlaceOrder", attributes: [])
      expect(cmd.inferred_event_name).to eq("PlacedOrder")
    end
  end
end

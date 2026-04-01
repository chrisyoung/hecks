require "spec_helper"

RSpec.describe Hecks::Conventions::DisplayContract do
  let(:domain) { BootedDomains.pizzas }
  let(:pizza_agg) { domain.aggregates.find { |a| a.name == "Pizza" } }
  let(:order_agg) { domain.aggregates.find { |a| a.name == "Order" } }

  describe ".home_aggregate_data" do
    it "returns command_names as a humanized comma-separated string" do
      data = described_class.home_aggregate_data(pizza_agg, "pizzas")
      expect(data[:command_names]).to eq("Create Pizza, Add Topping")
    end

    it "returns empty string when aggregate has zero commands" do
      empty_agg = double("Aggregate",
        name: "Empty",
        commands: [],
        attributes: [double(name: "id"), double(name: "created_at")],
        policies: [])
      data = described_class.home_aggregate_data(empty_agg, "empties")
      expect(data[:command_names]).to eq("")
    end

    it "returns the correct attribute count" do
      data = described_class.home_aggregate_data(pizza_agg, "pizzas")
      expect(data[:attributes]).to be > 0
    end
  end
end

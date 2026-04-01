require "spec_helper"

RSpec.describe Hecks::Conventions::DisplayContract do
  let(:domain) { BootedDomains.pizzas }

  describe ".home_aggregate_data" do
    it "returns command_names as a humanized comma-separated string" do
      pizza = domain.aggregates.find { |a| a.name == "Pizza" }
      data = described_class.home_aggregate_data(pizza, "pizzas")
      expect(data[:command_names]).to eq("Create Pizza, Add Topping")
    end

    it "returns an empty string when there are no commands" do
      agg = double("agg",
        name: "Empty",
        commands: [],
        attributes: [],
        policies: [])
      data = described_class.home_aggregate_data(agg, "empties")
      expect(data[:command_names]).to eq("")
    end
  end
end

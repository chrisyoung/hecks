require "spec_helper"

RSpec.describe Hecks::EventStorm::DomainBuilder do
  let(:source) do
    <<~STORM
      # Pizza Ordering

      ## Bounded Context: Ordering

      Actor: Customer

      Command: [Place Order]
        Aggregate: (Order)
        ReadModel: <Menu & Availability>
      Event: >>Order Placed<<

      Policy: {When Order Placed, Reserve Stock}

      Command: [Reserve Stock]
        Aggregate: (Inventory)
      Event: >>Stock Reserved<<

      ## Bounded Context: Fulfillment

      Command: [Start Preparation]
        Aggregate: (Kitchen Ticket)
        External: [[SMS Gateway]]
      Event: >>Preparation Started<<
    STORM
  end

  let(:parse_result) { Hecks::EventStorm::Parser.new(source).parse }
  subject(:domain) { described_class.new(parse_result, name: "PizzaOrdering").build }

  it "builds a domain with the correct name" do
    expect(domain.name).to eq("PizzaOrdering")
  end

  it "creates aggregates from all contexts" do
    expect(domain.aggregates.map(&:name)).to include("Order", "Inventory", "KitchenTicket")
  end

  describe "Order aggregate" do
    it "assigns commands to their aggregates" do
      order_agg = domain.aggregates.find { |a| a.name == "Order" }
      expect(order_agg.commands.map(&:name)).to include("PlaceOrder")
    end

    it "infers events from commands" do
      order_agg = domain.aggregates.find { |a| a.name == "Order" }
      expect(order_agg.events.map(&:name)).to include("PlacedOrder")
    end

    it "attaches read models to commands" do
      order_agg = domain.aggregates.find { |a| a.name == "Order" }
      cmd = order_agg.commands.find { |c| c.name == "PlaceOrder" }
      expect(cmd.read_models.map(&:name)).to include("Menu & Availability")
    end
  end

  describe "Inventory aggregate" do
    it "attaches policies to the aggregate owning the trigger" do
      inventory_agg = domain.aggregates.find { |a| a.name == "Inventory" }
      expect(inventory_agg.policies.size).to eq(1)
      expect(inventory_agg.policies.first.event_name).to eq("OrderPlaced")
      expect(inventory_agg.policies.first.trigger_command).to eq("ReserveStock")
    end
  end

  describe "KitchenTicket aggregate" do
    it "attaches external systems to commands" do
      kt = domain.aggregates.find { |a| a.name == "KitchenTicket" }
      cmd = kt.commands.find { |c| c.name == "StartPreparation" }
      expect(cmd.external_systems.map(&:name)).to include("SMS Gateway")
    end
  end
end

require "spec_helper"

RSpec.describe Hecks::EventStorm::Parser do
  describe "parsing a simple event storm" do
    let(:source) do
      <<~STORM
        # Pizza Ordering

        ## Bounded Context: Ordering

        Actor: Customer
          |
          v
        Command: [Place Order]
          Aggregate: (Order)
          ReadModel: <Menu & Availability>
          |
          v
        Event: >>Order Placed<<
          |
          v
        Policy: {When Order Placed, Reserve Inventory}
          |
          v
        Command: [Reserve Stock]
          Aggregate: (Inventory)
          |
          v
        Event: >>Stock Reserved<<

        ## Bounded Context: Fulfillment

        Command: [Start Preparation]
          Aggregate: (Kitchen Ticket)
          External: [[SMS Gateway]]
          |
          v
        Event: >>Preparation Started<<
      STORM
    end

    subject(:result) { described_class.new(source).parse }

    it "extracts the domain name" do
      expect(result.domain_name).to eq("Pizza Ordering")
    end

    it "extracts bounded contexts" do
      expect(result.contexts.size).to eq(2)
      expect(result.contexts.map(&:name)).to eq(["Ordering", "Fulfillment"])
    end

    describe "Ordering context elements" do
      let(:elements) { result.contexts.first.elements }

      it "finds actors" do
        actors = elements.select { |e| e.type == :actor }
        expect(actors.size).to eq(1)
        expect(actors.first.name).to eq("Customer")
      end

      it "finds commands with normalized names" do
        commands = elements.select { |e| e.type == :command }
        expect(commands.map(&:name)).to include("PlaceOrder", "ReserveStock")
      end

      it "finds events with normalized names" do
        events = elements.select { |e| e.type == :event }
        expect(events.map(&:name)).to include("OrderPlaced", "StockReserved")
      end

      it "associates aggregates with commands" do
        place_order = elements.find { |e| e.type == :command && e.name == "PlaceOrder" }
        expect(place_order.meta[:aggregate]).to eq("Order")
      end

      it "associates read models with commands" do
        place_order = elements.find { |e| e.type == :command && e.name == "PlaceOrder" }
        expect(place_order.meta[:read_models]).to include("Menu & Availability")
      end

      it "finds policies wired to the following command" do
        policies = elements.select { |e| e.type == :policy }
        expect(policies.size).to eq(1)
        expect(policies.first.meta[:event_name]).to eq("OrderPlaced")
        expect(policies.first.meta[:trigger]).to eq("ReserveStock")
      end
    end

    describe "Fulfillment context elements" do
      let(:elements) { result.contexts.last.elements }

      it "associates external systems with commands" do
        cmd = elements.find { |e| e.type == :command && e.name == "StartPreparation" }
        expect(cmd.meta[:external_systems]).to include("SMS Gateway")
      end
    end
  end

  describe "parsing without explicit contexts" do
    let(:source) do
      <<~STORM
        Command: [Create Pizza]
          Aggregate: (Pizza)
        Event: >>Pizza Created<<
      STORM
    end

    subject(:result) { described_class.new(source).parse }

    it "uses Default context" do
      expect(result.contexts.size).to eq(1)
      expect(result.contexts.first.name).to eq("Default")
    end
  end

  describe "name normalization" do
    let(:source) do
      <<~STORM
        Command: [place order]
        Event: >>order placed<<
      STORM
    end

    subject(:result) { described_class.new(source).parse }

    it "capitalizes each word and joins" do
      commands = result.contexts.first.elements.select { |e| e.type == :command }
      expect(commands.first.name).to eq("PlaceOrder")
    end
  end

  describe "hotspots" do
    let(:source) do
      <<~STORM
        !!Payment timeouts!!
        Command: [Process Payment]
          Aggregate: (Payment)
      STORM
    end

    subject(:result) { described_class.new(source).parse }

    it "captures hotspots" do
      hotspots = result.contexts.first.elements.select { |e| e.type == :hotspot }
      expect(hotspots.size).to eq(1)
      expect(hotspots.first.name).to eq("Payment timeouts")
    end
  end
end

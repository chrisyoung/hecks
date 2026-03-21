require "spec_helper"

RSpec.describe Hecks::EventStorm::YamlParser do
  describe "parsing a YAML event storm" do
    let(:source) do
      <<~YAML
        domain: Pizza Ordering

        contexts:
          Ordering:
            aggregates:
              Order:
                commands:
                  Place Order:
                    actor: Customer
                    read_models: [Menu & Availability]
                    event: Order Placed
                  Confirm Order:
                    event: Order Confirmed
                policies:
                  Reserve Inventory:
                    on: Order Placed
                    trigger: Reserve Stock

              Inventory:
                commands:
                  Reserve Stock:
                    event: Stock Reserved

          Fulfillment:
            aggregates:
              Kitchen Ticket:
                commands:
                  Start Preparation:
                    external_systems: [SMS Gateway]
                    event: Preparation Started
      YAML
    end

    subject(:result) { described_class.new(source).parse }

    it "extracts the domain name" do
      expect(result.domain_name).to eq("Pizza Ordering")
    end

    it "extracts bounded contexts" do
      expect(result.contexts.size).to eq(2)
      expect(result.contexts.map(&:name)).to eq(["Ordering", "Fulfillment"])
    end

    describe "Ordering context" do
      let(:elements) { result.contexts.first.elements }

      it "finds commands with normalized names" do
        commands = elements.select { |e| e.type == :command }
        expect(commands.map(&:name)).to include("PlaceOrder", "ConfirmOrder", "ReserveStock")
      end

      it "finds events with normalized names" do
        events = elements.select { |e| e.type == :event }
        expect(events.map(&:name)).to include("OrderPlaced", "OrderConfirmed", "StockReserved")
      end

      it "associates aggregates with commands" do
        place_order = elements.find { |e| e.type == :command && e.name == "PlaceOrder" }
        expect(place_order.meta[:aggregate]).to eq("Order")
      end

      it "associates read models with commands" do
        place_order = elements.find { |e| e.type == :command && e.name == "PlaceOrder" }
        expect(place_order.meta[:read_models]).to include("Menu & Availability")
      end

      it "finds actors" do
        actors = elements.select { |e| e.type == :actor }
        expect(actors.map(&:name)).to include("Customer")
      end

      it "finds policies with wiring" do
        policies = elements.select { |e| e.type == :policy }
        expect(policies.size).to eq(1)
        expect(policies.first.meta[:event_name]).to eq("OrderPlaced")
        expect(policies.first.meta[:trigger]).to eq("ReserveStock")
      end
    end

    describe "Fulfillment context" do
      let(:elements) { result.contexts.last.elements }

      it "associates external systems with commands" do
        cmd = elements.find { |e| e.type == :command && e.name == "StartPreparation" }
        expect(cmd.meta[:external_systems]).to include("SMS Gateway")
      end
    end
  end

  describe "parsing without explicit contexts" do
    let(:source) do
      <<~YAML
        domain: Simple

        aggregates:
          Pizza:
            commands:
              Create Pizza:
                event: Pizza Created
      YAML
    end

    subject(:result) { described_class.new(source).parse }

    it "uses Default context" do
      expect(result.contexts.size).to eq(1)
      expect(result.contexts.first.name).to eq("Default")
    end

    it "parses the aggregate" do
      commands = result.contexts.first.elements.select { |e| e.type == :command }
      expect(commands.first.name).to eq("CreatePizza")
    end
  end

  describe "hotspots" do
    let(:source) do
      <<~YAML
        domain: Test

        aggregates:
          Payment:
            commands:
              Process Payment: {}
            hotspots:
              - Payment timeouts
              - Retry logic unclear
      YAML
    end

    subject(:result) { described_class.new(source).parse }

    it "captures hotspots" do
      hotspots = result.contexts.first.elements.select { |e| e.type == :hotspot }
      expect(hotspots.size).to eq(2)
      expect(hotspots.map(&:name)).to eq(["Payment timeouts", "Retry logic unclear"])
    end
  end

  describe "format parity with ASCII parser" do
    let(:yaml_source) do
      <<~YAML
        domain: Test

        contexts:
          Ordering:
            aggregates:
              Order:
                commands:
                  Place Order:
                    read_models: [Menu]
                    event: Order Placed
                policies:
                  Start Payment:
                    on: Order Placed
                    trigger: Process Payment
              Payment:
                commands:
                  Process Payment:
                    external_systems: [Stripe]
      YAML
    end

    let(:ascii_source) do
      <<~ASCII
        # Test

        ## Bounded Context: Ordering

        Command: [Place Order]
          Aggregate: (Order)
          ReadModel: <Menu>
        Event: >>Order Placed<<

        Policy: {When Order Placed, Start Payment}

        Command: [Process Payment]
          Aggregate: (Payment)
          External: [[Stripe]]
      ASCII
    end

    it "produces the same aggregates and commands" do
      yaml_result = Hecks.from_event_storm(yaml_source, name: "Test")
      ascii_result = Hecks.from_event_storm(ascii_source, name: "Test")

      yaml_aggs = yaml_result.domain.aggregates.map(&:name).sort
      ascii_aggs = ascii_result.domain.aggregates.map(&:name).sort
      expect(yaml_aggs).to eq(ascii_aggs)

      yaml_cmds = yaml_result.domain.aggregates.flat_map { |a| a.commands.map(&:name) }.sort
      ascii_cmds = ascii_result.domain.aggregates.flat_map { |a| a.commands.map(&:name) }.sort
      expect(yaml_cmds).to eq(ascii_cmds)
    end
  end

  describe "end-to-end via Hecks.from_event_storm" do
    let(:source) do
      <<~YAML
        domain: Pizzas

        aggregates:
          Pizza:
            commands:
              Create Pizza:
                event: Pizza Created
      YAML
    end

    it "auto-detects YAML format from content" do
      result = Hecks.from_event_storm(source)
      expect(result.domain.name).to eq("Pizzas")
      expect(result.domain.aggregates.first.name).to eq("Pizza")
    end

    it "auto-detects YAML format from file extension" do
      result = Hecks.from_event_storm("examples/pizzas/event_storm.yml")
      expect(result.domain).to be_a(Hecks::DomainModel::Domain)
      expect(result.domain.contexts.map(&:name)).to include("Ordering", "Fulfillment")
    end
  end
end

require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Commands::CommandBus do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  before { Hecks.load(domain) }

  let(:event_bus) { Hecks::Services::EventBus.new }
  subject(:bus) { described_class.new(domain: domain, event_bus: event_bus) }

  describe "#dispatch" do
    it "dispatches a command and returns an event" do
      event = bus.dispatch("CreatePizza", name: "Margherita")
      expect(event.name).to eq("Margherita")
    end

    it "publishes the event to the event bus" do
      bus.dispatch("CreatePizza", name: "Margherita")
      expect(event_bus.events.size).to eq(1)
    end

    it "raises for unknown commands" do
      expect { bus.dispatch("FlyToMoon") }.to raise_error(/Unknown command/)
    end
  end

  describe "#use (middleware)" do
    it "runs middleware around the command" do
      log = []
      bus.use(:logging) do |command, next_handler|
        log << "before:#{command.name}"
        result = next_handler.call
        log << "after"
        result
      end

      bus.dispatch("CreatePizza", name: "Margherita")
      expect(log).to eq(["before:Margherita", "after"])
    end

    it "middleware can modify the result" do
      bus.use(:wrapper) do |command, next_handler|
        event = next_handler.call
        { event: event, extra: "data" }
      end

      result = bus.dispatch("CreatePizza", name: "Margherita")
      expect(result).to be_a(Hash)
      expect(result[:extra]).to eq("data")
    end

    it "middleware can reject a command" do
      bus.use(:auth) do |command, next_handler|
        raise "Not authorized" if command.name == "Margherita"
        next_handler.call
      end

      expect { bus.dispatch("CreatePizza", name: "Margherita") }.to raise_error("Not authorized")
      expect(event_bus.events).to be_empty
    end

    it "chains multiple middleware in order" do
      order = []

      bus.use(:first) do |command, next_handler|
        order << "first:before"
        result = next_handler.call
        order << "first:after"
        result
      end

      bus.use(:second) do |command, next_handler|
        order << "second:before"
        result = next_handler.call
        order << "second:after"
        result
      end

      bus.dispatch("CreatePizza", name: "Margherita")
      expect(order).to eq(["first:before", "second:before", "second:after", "first:after"])
    end
  end

  describe "integration with Application" do
    it "middleware registered on the app flows through to commands" do
      log = []
      app = Hecks.load(domain)
      app.use(:logging) do |command, next_handler|
        log << command.class.name.split("::").last
        next_handler.call
      end

      PizzasDomain::Pizza.create(name: "Test")
      expect(log).to include("CreatePizza")
    end
  end
end

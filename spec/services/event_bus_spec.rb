require "spec_helper"

RSpec.describe Hecks::Services::EventBus do
  subject(:bus) { described_class.new }

  let(:event) do
    double("Event", class: double(name: "PizzasDomain::Pizza::Events::CreatedPizza"))
  end

  describe "#publish" do
    it "stores the event" do
      bus.publish(event)
      expect(bus.events).to eq([event])
    end

    it "notifies subscribers" do
      received = nil
      bus.subscribe("CreatedPizza") { |e| received = e }
      bus.publish(event)
      expect(received).to eq(event)
    end

    it "notifies multiple subscribers" do
      count = 0
      bus.subscribe("CreatedPizza") { count += 1 }
      bus.subscribe("CreatedPizza") { count += 1 }
      bus.publish(event)
      expect(count).to eq(2)
    end

    it "does not notify unrelated subscribers" do
      called = false
      bus.subscribe("PlacedOrder") { called = true }
      bus.publish(event)
      expect(called).to be false
    end
  end

  describe "#clear" do
    it "clears events" do
      bus.publish(event)
      bus.clear
      expect(bus.events).to be_empty
    end
  end
end

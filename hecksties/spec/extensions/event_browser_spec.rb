require "spec_helper"
require "hecks/extensions/web_explorer/event_introspector"
require "hecks/extensions/web_explorer/renderer"

RSpec.describe Hecks::WebExplorer::EventIntrospector do
  let(:domain) { BootedDomains.pizzas }

  before { BootedDomains.boot(domain) }

  let(:event_bus) { Hecks::EventBus.new }

  let(:pizza_event) do
    # Simulate a real event structure with nested class name
    klass = Class.new do
      attr_reader :aggregate_id, :name, :occurred_at

      def initialize(aggregate_id:, name:, occurred_at: Time.now)
        @aggregate_id = aggregate_id
        @name = name
        @occurred_at = occurred_at
      end
    end
    stub_const("PizzasDomain::Pizza::Events::CreatedPizza", klass)
    klass.new(aggregate_id: "abc-123", name: "Margherita")
  end

  let(:order_event) do
    klass = Class.new do
      attr_reader :aggregate_id, :quantity, :occurred_at

      def initialize(aggregate_id:, quantity:, occurred_at: Time.now)
        @aggregate_id = aggregate_id
        @quantity = quantity
        @occurred_at = occurred_at
      end
    end
    stub_const("PizzasDomain::Order::Events::PlacedOrder", klass)
    klass.new(aggregate_id: "def-456", quantity: 3)
  end

  before do
    event_bus.publish(pizza_event)
    event_bus.publish(order_event)
  end

  subject(:introspector) { described_class.new(event_bus) }

  describe "#all_entries" do
    it "returns all events as structured hashes" do
      entries = introspector.all_entries
      expect(entries.size).to eq(2)
      expect(entries.first[:type]).to eq("PlacedOrder")
      expect(entries.last[:type]).to eq("CreatedPizza")
    end

    it "filters by type" do
      entries = introspector.all_entries(type_filter: "CreatedPizza")
      expect(entries.size).to eq(1)
      expect(entries.first[:type]).to eq("CreatedPizza")
    end

    it "filters by aggregate" do
      entries = introspector.all_entries(aggregate_filter: "Order")
      expect(entries.size).to eq(1)
      expect(entries.first[:aggregate]).to eq("Order")
    end

    it "returns entries in reverse chronological order" do
      entries = introspector.all_entries
      expect(entries.first[:type]).to eq("PlacedOrder")
      expect(entries.last[:type]).to eq("CreatedPizza")
    end

    it "extracts payload from event attributes" do
      entries = introspector.all_entries(type_filter: "CreatedPizza")
      payload = entries.first[:payload]
      expect(payload).to include("aggregate_id" => "abc-123", "name" => "Margherita")
    end

    it "includes occurred_at timestamp" do
      entries = introspector.all_entries
      entries.each { |e| expect(e[:occurred_at]).to match(/\d{4}-\d{2}-\d{2}/) }
    end

    it "ignores empty filter strings" do
      entries = introspector.all_entries(type_filter: "", aggregate_filter: "")
      expect(entries.size).to eq(2)
    end
  end

  describe "#event_types" do
    it "returns unique sorted event type names" do
      expect(introspector.event_types).to eq(["CreatedPizza", "PlacedOrder"])
    end
  end

  describe "#aggregate_types" do
    it "returns unique sorted aggregate type names" do
      expect(introspector.aggregate_types).to eq(["Order", "Pizza"])
    end
  end
end

RSpec.describe "Events template rendering" do
  let(:views_dir) { File.expand_path("../../lib/hecks/extensions/web_explorer/views", __dir__) }
  let(:renderer) { Hecks::WebExplorer::Renderer.new(views_dir) }

  it "renders the events template with entries" do
    html = renderer.render(:events, {
      title: "Events", brand: "Test", nav_items: [],
      entries: [
        { type: "CreatedPizza", aggregate: "Pizza", occurred_at: "2026-04-01 12:00:00",
          payload: { "name" => "Margherita" } }
      ],
      total: 1, event_types: ["CreatedPizza"], aggregate_types: ["Pizza"],
      type_filter: nil, aggregate_filter: nil, events_href: "/events",
      skip_layout: true
    })
    expect(html).to include("Event Log")
    expect(html).to include("CreatedPizza")
    expect(html).to include("Pizza")
    expect(html).to include("Margherita")
  end

  it "renders empty state when no events exist" do
    html = renderer.render(:events, {
      title: "Events", brand: "Test", nav_items: [],
      entries: [], total: 0, event_types: [], aggregate_types: [],
      type_filter: nil, aggregate_filter: nil, events_href: "/events",
      skip_layout: true
    })
    expect(html).to include("No events recorded yet")
  end
end

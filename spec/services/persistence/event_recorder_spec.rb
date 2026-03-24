require "spec_helper"
require "tmpdir"
require "sequel"

RSpec.describe Hecks::Services::Persistence::EventRecorder do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end
      end

      aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer

        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end
      end
    end
  end

  let(:db) { Sequel.sqlite }

  before do
    db.create_table(:pizzas) do
      String :id, primary_key: true, size: 36
      String :name
      String :style
      String :created_at
      String :updated_at
    end

    db.create_table(:orders) do
      String :id, primary_key: true, size: 36
      String :pizza_id
      Integer :quantity
      String :status
      String :created_at
      String :updated_at
    end

    Hecks.load(domain)

    domain.aggregates.each do |agg|
      gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: "PizzasDomain")
      eval(gen.generate, TOPLEVEL_BINDING)
    end

    pizza_repo = PizzasDomain::Adapters::PizzaSqlRepository.new(db)
    order_repo = PizzasDomain::Adapters::OrderSqlRepository.new(db)
    @app = Hecks.load(domain) do
      adapter "Pizza", pizza_repo
      adapter "Order", order_repo
    end

    @recorder = described_class.new(db)
    Hecks::Services::Persistence.bind_event_recorder(PizzasDomain::Pizza, @recorder)
    Hecks::Services::Persistence.bind_event_recorder(PizzasDomain::Order, @recorder)
  end

  describe "#record and #history" do
    it "records events from create commands" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      events = PizzasDomain::Pizza.history(pizza.id)
      expect(events.size).to eq(1)
      expect(events.first[:event_type]).to eq("CreatedPizza")
      expect(events.first[:data]["name"]).to eq("Margherita")
    end

    it "records events from update commands" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      PizzasDomain::Order.place(pizza_id: pizza.id, quantity: 3)
      events = PizzasDomain::Order.history(PizzasDomain::Order.first.id)
      expect(events.size).to eq(1)
      expect(events.first[:event_type]).to eq("PlacedOrder")
    end

    it "tracks version numbers per stream" do
      pizza = PizzasDomain::Pizza.create(name: "First", style: "Classic")
      PizzasDomain::Pizza.create(name: "Second", style: "Spicy")

      events = @recorder.all_events
      first_stream = events.select { |e| e[:stream_id] == "Pizza-#{pizza.id}" }
      expect(first_stream.first[:version]).to eq(1)
    end

    it "creates the domain_events table automatically" do
      expect(db.table_exists?(:domain_events)).to be true
    end
  end

  describe ".history on aggregate" do
    it "returns events for a specific aggregate" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")

      history = PizzasDomain::Pizza.history(pizza.id)
      expect(history.size).to eq(1)
      expect(history.first[:data]["name"]).to eq("Margherita")
    end
  end
end

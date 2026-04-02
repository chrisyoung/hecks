require "spec_helper"

RSpec.describe "Time Travel" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end

        command "RenamePizza" do
          reference_to "Pizza"
          attribute :name, String
        end
      end
    end
  end

  let!(:app) { Hecks.load(domain) }

  describe Hecks::EventStore do
    let(:store) { Hecks::EventStore.new }

    let(:event1) do
      PizzasDomain::Pizza::Events::CreatedPizza.new(
        aggregate_id: "pizza-1", name: "Margherita", style: "Classic"
      )
    end

    let(:event2) do
      PizzasDomain::Pizza::Events::RenamedPizza.new(
        aggregate_id: "pizza-1", name: "Pepperoni"
      )
    end

    it "appends events with incrementing versions" do
      store.append("Pizza-pizza-1", event1)
      store.append("Pizza-pizza-1", event2)

      records = store.read_stream("Pizza-pizza-1")
      expect(records.size).to eq(2)
      expect(records[0][:version]).to eq(1)
      expect(records[1][:version]).to eq(2)
    end

    it "reads stream up to a version" do
      store.append("Pizza-pizza-1", event1)
      store.append("Pizza-pizza-1", event2)

      records = store.read_stream_to_version("Pizza-pizza-1", version: 1)
      expect(records.size).to eq(1)
      expect(records.first[:event_type]).to eq("CreatedPizza")
    end

    it "reads stream until a timestamp" do
      store.append("Pizza-pizza-1", event1)
      cutoff = Time.now + 0.001
      sleep 0.002
      e2 = PizzasDomain::Pizza::Events::RenamedPizza.new(
        aggregate_id: "pizza-1", name: "Pepperoni"
      )
      store.append("Pizza-pizza-1", e2)

      records = store.read_stream_until("Pizza-pizza-1", timestamp: cutoff)
      expect(records.size).to eq(1)
    end

    it "reports stream version" do
      expect(store.stream_version("Pizza-pizza-1")).to eq(0)
      store.append("Pizza-pizza-1", event1)
      expect(store.stream_version("Pizza-pizza-1")).to eq(1)
    end

    it "clears all records" do
      store.append("Pizza-pizza-1", event1)
      store.clear
      expect(store.records).to be_empty
    end
  end

  describe "Runtime#event_store" do
    it "exposes the event store" do
      expect(app.event_store).to be_a(Hecks::EventStore)
    end

    it "automatically records events when commands execute" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      records = app.event_store.read_stream("Pizza-#{pizza.id}")
      expect(records.size).to eq(1)
      expect(records.first[:event_type]).to eq("CreatedPizza")
    end
  end

  describe "Runtime#as_of" do
    it "reconstitutes aggregate at a past point in time" do
      pizza = PizzasDomain::Pizza.create(name: "Original", style: "Classic")
      snapshot_time = Time.now + 0.001
      sleep 0.002
      PizzasDomain::Pizza.rename(pizza: pizza.id, name: "Updated")

      past_pizza = app.as_of(snapshot_time).find("Pizza", pizza.id)
      expect(past_pizza.name).to eq("Original")
    end

    it "returns nil when no events exist before timestamp" do
      result = app.as_of(Time.now - 3600).find("Pizza", "nonexistent")
      expect(result).to be_nil
    end

    it "has a readable inspect" do
      proxy = app.as_of(Time.now)
      expect(proxy.inspect).to include("AsOfProxy")
    end
  end

  describe "Runtime#at_version" do
    it "reconstitutes aggregate at a specific version" do
      pizza = PizzasDomain::Pizza.create(name: "V1", style: "Classic")
      PizzasDomain::Pizza.rename(pizza: pizza.id, name: "V2")

      v1_pizza = app.at_version("Pizza", pizza.id, version: 1)
      expect(v1_pizza.name).to eq("V1")

      v2_pizza = app.at_version("Pizza", pizza.id, version: 2)
      expect(v2_pizza.name).to eq("V2")
    end

    it "returns nil for version 0" do
      result = app.at_version("Pizza", "missing", version: 0)
      expect(result).to be_nil
    end
  end

  describe "Runtime#reconstitute_at_version" do
    it "is an alias for at_version" do
      pizza = PizzasDomain::Pizza.create(name: "Test", style: "NY")
      v1 = app.reconstitute_at_version("Pizza", pizza.id, version: 1)
      expect(v1.name).to eq("Test")
    end
  end
end

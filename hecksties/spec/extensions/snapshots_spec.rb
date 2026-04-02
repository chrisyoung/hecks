require "spec_helper"
require "hecks/extensions/snapshots"

RSpec.describe "Aggregate Snapshots" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String

        command "CreatePizza" do
          attribute :name, String
          attribute :description, String
        end

        command "UpdatePizza" do
          attribute :pizza, String
          attribute :name, String
          attribute :description, String
        end

        apply "CreatedPizza" do |_aggregate, data|
          PizzasDomain::Pizza.new(
            id: data["aggregate_id"],
            name: data["name"],
            description: data["description"]
          )
        end

        apply "UpdatedPizza" do |aggregate, data|
          PizzasDomain::Pizza.new(
            id: aggregate.id,
            name: data["name"] || aggregate.name,
            description: data["description"] || aggregate.description
          )
        end
      end
    end
  end

  describe Hecks::Snapshots::MemorySnapshotStore do
    let(:store) { described_class.new }

    it "saves and loads a snapshot" do
      store.save_snapshot("Pizza", "abc-123", version: 5, state: { name: "Margherita" })
      snap = store.load_snapshot("Pizza", "abc-123")

      expect(snap[:aggregate_type]).to eq("Pizza")
      expect(snap[:aggregate_id]).to eq("abc-123")
      expect(snap[:version]).to eq(5)
      expect(snap[:state]).to eq({ name: "Margherita" })
      expect(snap[:taken_at]).to be_a(Time)
    end

    it "returns nil for missing snapshot" do
      expect(store.load_snapshot("Pizza", "nonexistent")).to be_nil
    end

    it "overwrites previous snapshot for same aggregate" do
      store.save_snapshot("Pizza", "abc", version: 1, state: { name: "V1" })
      store.save_snapshot("Pizza", "abc", version: 5, state: { name: "V5" })

      snap = store.load_snapshot("Pizza", "abc")
      expect(snap[:version]).to eq(5)
      expect(snap[:state][:name]).to eq("V5")
    end

    it "clears all snapshots" do
      store.save_snapshot("Pizza", "1", version: 1, state: {})
      store.save_snapshot("Pizza", "2", version: 1, state: {})
      store.clear
      expect(store.load_snapshot("Pizza", "1")).to be_nil
      expect(store.load_snapshot("Pizza", "2")).to be_nil
    end
  end

  describe Hecks::Snapshots::Reconstitution do
    it "reconstitutes from full event history without snapshot" do
      app = Hecks.load(domain)
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")

      store = Hecks::Snapshots::MemorySnapshotStore.new
      recorder = MockEventRecorder.new([
        { event_type: "CreatedPizza", data: { "aggregate_id" => pizza.id, "name" => "Margherita", "description" => "Classic" }, version: 1 }
      ])

      result = described_class.reconstitute(
        PizzasDomain::Pizza, pizza.id,
        snapshot_store: store,
        event_recorder: recorder
      )

      expect(result.name).to eq("Margherita")
      expect(result.description).to eq("Classic")
    end

    it "reconstitutes from snapshot plus subsequent events" do
      app = Hecks.load(domain)

      store = Hecks::Snapshots::MemorySnapshotStore.new
      store.save_snapshot("Pizza", "abc-123", version: 5, state: {
        id: "abc-123", name: "Margherita", description: "Classic"
      })

      recorder = MockEventRecorder.new([
        { event_type: "CreatedPizza", data: { "aggregate_id" => "abc-123", "name" => "Margherita", "description" => "Classic" }, version: 1 },
        { event_type: "UpdatedPizza", data: { "name" => "Supreme", "description" => "Loaded" }, version: 6 }
      ])

      result = described_class.reconstitute(
        PizzasDomain::Pizza, "abc-123",
        snapshot_store: store,
        event_recorder: recorder
      )

      expect(result.name).to eq("Supreme")
      expect(result.description).to eq("Loaded")
    end

    it "returns nil when no events exist" do
      app = Hecks.load(domain)
      store = Hecks::Snapshots::MemorySnapshotStore.new
      recorder = MockEventRecorder.new([])

      result = described_class.reconstitute(
        PizzasDomain::Pizza, "nonexistent",
        snapshot_store: store,
        event_recorder: recorder
      )

      expect(result).to be_nil
    end
  end

  describe "DSL apply blocks" do
    it "registers appliers on the aggregate class at boot" do
      app = Hecks.load(domain)
      appliers = PizzasDomain::Pizza.instance_variable_get(:@__hecks_appliers__)

      expect(appliers).to be_a(Hash)
      expect(appliers.keys).to include("CreatedPizza", "UpdatedPizza")
    end
  end

  describe "extension registration" do
    it "wires snapshot store and auto-snapshot on extend" do
      app = Hecks.load(domain)
      app.extend(:snapshots, threshold: 3)

      expect(Hecks.snapshot_store).to be_a(Hecks::Snapshots::MemorySnapshotStore)
    end

    it "takes auto-snapshot after threshold events across streams" do
      app = Hecks.load(domain)

      store = Hecks::Snapshots::MemorySnapshotStore.new
      Hecks.instance_variable_set(:@_snapshot_store, store)
      Hecks.define_singleton_method(:snapshot_store) { @_snapshot_store }

      # Manually wire with a low threshold
      resolver = ->(agg_type, agg_id) {
        PizzasDomain::Pizza.find(agg_id) if agg_type == "Pizza"
      }

      Hecks::Snapshots::AutoSnapshot.new(
        snapshot_store: store,
        event_bus: app.event_bus,
        threshold: 1,
        aggregate_resolver: resolver
      )

      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")

      snap = store.load_snapshot("Pizza", pizza.id)
      expect(snap).not_to be_nil
      expect(snap[:state][:name]).to eq("Margherita")
    end
  end
end

# Minimal mock event recorder for reconstitution tests
class MockEventRecorder
  def initialize(events)
    @events = events
  end

  def history(_type, _id)
    @events
  end
end

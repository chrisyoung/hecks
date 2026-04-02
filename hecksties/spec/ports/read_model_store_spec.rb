require "spec_helper"
require "hecks/ports/read_model_store"

RSpec.describe Hecks::ReadModelStore do
  let(:domain) do
    Hecks.domain "RmsTest" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  let(:app) { Hecks.load(domain) }
  let(:adapter) { app; RmsTestDomain::Adapters::WidgetMemoryRepository.new }
  let(:store) { described_class.new(adapter: adapter) }

  before { app }

  it "exposes the underlying adapter via #read" do
    expect(store.read).to eq(adapter)
  end

  it "saves an aggregate via #update" do
    widget = RmsTestDomain::Widget.create(name: "Bolt")
    store.update(widget)
    expect(store.count).to eq(1)
  end

  it "finds by id" do
    widget = RmsTestDomain::Widget.create(name: "Nut")
    store.update(widget)
    expect(store.find(widget.id).name).to eq("Nut")
  end

  it "clears all data" do
    widget = RmsTestDomain::Widget.create(name: "Screw")
    store.update(widget)
    store.clear
    expect(store.count).to eq(0)
  end

  it "delegates all to adapter" do
    w1 = RmsTestDomain::Widget.create(name: "A")
    w2 = RmsTestDomain::Widget.create(name: "B")
    store.update(w1)
    store.update(w2)
    expect(store.all.size).to eq(2)
  end

  it "delegates delete to adapter" do
    widget = RmsTestDomain::Widget.create(name: "Gone")
    store.update(widget)
    store.delete(widget.id)
    expect(store.count).to eq(0)
  end
end

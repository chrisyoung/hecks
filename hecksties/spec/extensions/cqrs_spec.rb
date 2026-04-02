require "spec_helper"
require "hecks/extensions/cqrs"

RSpec.describe HecksCqrs do
  let(:mod) do
    m = Module.new
    m.extend(Hecks::DomainConnections)
    m
  end

  describe ".active?" do
    it "returns false when no connections configured" do
      expect(HecksCqrs.active?(mod)).to be false
    end

    it "returns false with a single unnamed connection" do
      mod.extend(:sqlite)
      expect(HecksCqrs.active?(mod)).to be false
    end

    it "returns true with multiple named connections" do
      mod.extend(:sqlite, as: :write)
      mod.extend(:sqlite, as: :read, database: "read.db")
      expect(HecksCqrs.active?(mod)).to be true
    end
  end

  describe ".connection_for" do
    it "returns nil when no connections configured" do
      expect(HecksCqrs.connection_for(mod, :write)).to be_nil
    end

    it "returns config for a named connection" do
      mod.extend(:sqlite, as: :write)
      expect(HecksCqrs.connection_for(mod, :write).type).to eq(:sqlite)
    end

    it "returns config for :default unnamed connection" do
      mod.extend(:sqlite)
      expect(HecksCqrs.connection_for(mod, :default).type).to eq(:sqlite)
    end

    it "returns nil for unknown connection name" do
      mod.extend(:sqlite, as: :write)
      expect(HecksCqrs.connection_for(mod, :read)).to be_nil
    end
  end

  describe "CQRS read/write separation" do
    let(:domain) do
      Hecks.domain "CqrsTest" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
    end

    it "routes commands to write repo and queries to read store" do
      app = Hecks.load(domain)

      # Create via write side
      CqrsTestDomain::Widget.create(name: "Sprocket")
      expect(app["Widget"].all.size).to eq(1)

      # Enable CQRS with a separate read repo
      read_adapter = CqrsTestDomain::Adapters::WidgetMemoryRepository.new
      app.enable_cqrs("Widget", read_repo: read_adapter)

      # Read store starts empty
      expect(app.read_store_for("Widget").count).to eq(0)

      # Creating another widget syncs to read store via event
      CqrsTestDomain::Widget.create(name: "Gadget")

      # Write repo has both
      expect(app["Widget"].all.size).to eq(2)

      # Read store was synced by the event handler
      expect(app.read_store_for("Widget").count).to eq(2)
    end

    it "rebinds class-level read methods to read store" do
      app = Hecks.load(domain)

      read_adapter = CqrsTestDomain::Adapters::WidgetMemoryRepository.new
      app.enable_cqrs("Widget", read_repo: read_adapter)

      # Write directly to the write repo
      w = CqrsTestDomain::Widget.create(name: "Alpha")

      # Class read methods (find, all, count) route to read store
      # The read store was synced by the event auto-sync
      expect(CqrsTestDomain::Widget.all.map(&:name)).to include("Alpha")
      expect(CqrsTestDomain::Widget.count).to eq(1)
      expect(CqrsTestDomain::Widget.find(w.id).name).to eq("Alpha")
    end

    it "reports cqrs? status" do
      app = Hecks.load(domain)

      expect(app.cqrs?).to be false
      expect(app.cqrs?("Widget")).to be false

      read_adapter = CqrsTestDomain::Adapters::WidgetMemoryRepository.new
      app.enable_cqrs("Widget", read_repo: read_adapter)

      expect(app.cqrs?).to be true
      expect(app.cqrs?("Widget")).to be true
    end

    it "is backward compatible when no read store registered" do
      app = Hecks.load(domain)

      CqrsTestDomain::Widget.create(name: "Solo")
      expect(CqrsTestDomain::Widget.all.size).to eq(1)
      expect(CqrsTestDomain::Widget.find(CqrsTestDomain::Widget.first.id).name).to eq("Solo")
      expect(app.cqrs?).to be false
    end
  end

  describe "ReadModelStore" do
    before { require "hecks/ports/read_model_store" }

    let(:domain) do
      Hecks.domain "RmTest" do
        aggregate "Item" do
          attribute :title, String
          command "CreateItem" do
            attribute :title, String
          end
        end
      end
    end

    it "provides update, read, and clear" do
      app = Hecks.load(domain)
      adapter = RmTestDomain::Adapters::ItemMemoryRepository.new
      store = Hecks::ReadModelStore.new(adapter: adapter)

      item = RmTestDomain::Item.create(title: "Hello")
      store.update(item)

      expect(store.read.all.size).to eq(1)
      expect(store.find(item.id).title).to eq("Hello")
      expect(store.count).to eq(1)

      store.clear
      expect(store.count).to eq(0)
    end
  end
end

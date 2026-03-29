require "spec_helper"

RSpec.describe Hecks::DomainConnections do
  let(:mod) do
    m = Module.new
    m.extend(Hecks::DomainConnections)
    m
  end

  describe "#extend with persistence" do
    it "stores unnamed adapter under :default" do
      mod.extend(:sqlite)
      expect(mod.connections[:persist][:default]).to eq({ type: :sqlite })
    end

    it "accepts additional options" do
      mod.extend(:sqlite, database: "test.db")
      expect(mod.connections[:persist][:default]).to eq({ type: :sqlite, database: "test.db" })
    end
  end

  describe "#extend with domain module (listen)" do
    it "records a source domain" do
      source = Module.new
      mod.extend(source)
      expect(mod.connections[:listens]).to include(source)
    end

    it "accumulates multiple sources" do
      s1 = Module.new
      s2 = Module.new
      mod.extend(s1)
      mod.extend(s2)
      expect(mod.connections[:listens]).to eq([s1, s2])
    end
  end

  describe "#extend with outbound handler" do
    it "records a callable handler" do
      handler = ->(event) { event }
      mod.extend(:audit, handler)
      entry = mod.connections[:sends].last
      expect(entry[:name]).to eq(:audit)
      expect(entry[:handler]).to eq(handler)
    end

    it "accepts a block handler" do
      mod.extend(:audit) { |event| event }
      entry = mod.connections[:sends].last
      expect(entry[:name]).to eq(:audit)
      expect(entry[:handler]).to be_a(Proc)
    end

    it "treats symbol + kwargs as outbound when not persistence" do
      mod.extend(:slack, webhook: "https://hooks.slack.com/x")
      entry = mod.connections[:sends].last
      expect(entry[:name]).to eq(:slack)
      expect(entry[:webhook]).to eq("https://hooks.slack.com/x")
    end
  end

  describe "#extend with middleware" do
    it "records a middleware extension" do
      mod.extend(:tenancy)
      expect(mod.connections[:extensions]).to include({ name: :tenancy })
    end
  end

  describe "#connections" do
    it "returns default when nothing is configured" do
      expect(mod.connections).to eq({ persist: {}, listens: [], sends: [], extensions: [] })
    end
  end

  describe "#event_bus" do
    it "is nil by default" do
      expect(mod.event_bus).to be_nil
    end
  end
end

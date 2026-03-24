require "spec_helper"

RSpec.describe Hecks::DomainConnections do
  let(:mod) do
    m = Module.new
    m.extend(Hecks::DomainConnections)
    m
  end

  describe "#persist_to" do
    it "stores the persistence adapter config" do
      mod.persist_to(:sqlite)
      expect(mod.connections[:persist]).to eq({ type: :sqlite })
    end

    it "accepts additional options" do
      mod.persist_to(:sqlite, database: "test.db")
      expect(mod.connections[:persist]).to eq({ type: :sqlite, database: "test.db" })
    end
  end

  describe "#listens_to" do
    it "records a source domain" do
      source = Module.new
      mod.listens_to(source)
      expect(mod.connections[:listens]).to include(source)
    end

    it "accumulates multiple sources" do
      s1 = Module.new
      s2 = Module.new
      mod.listens_to(s1)
      mod.listens_to(s2)
      expect(mod.connections[:listens]).to eq([s1, s2])
    end
  end

  describe "#sends_to" do
    it "records a handler adapter" do
      handler = Object.new
      mod.sends_to(:notifications, handler)
      entry = mod.connections[:sends].last
      expect(entry[:name]).to eq(:notifications)
      expect(entry[:handler]).to eq(handler)
    end

    it "accepts a block handler" do
      mod.sends_to(:audit) { |event| event }
      entry = mod.connections[:sends].last
      expect(entry[:name]).to eq(:audit)
      expect(entry[:handler]).to be_a(Proc)
    end
  end

  describe "#connections" do
    it "returns default when nothing is configured" do
      expect(mod.connections).to eq({ persist: nil, listens: [], sends: [] })
    end
  end

  describe "#event_bus" do
    it "is nil by default" do
      expect(mod.event_bus).to be_nil
    end
  end
end

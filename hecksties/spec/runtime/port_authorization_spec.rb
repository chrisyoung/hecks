require "spec_helper"

RSpec.describe "Port Authorization" do
  let(:domain) do
    Hecks.domain "PortTest" do
      aggregate "Pizza" do
        attribute :name, String

        # port declarations are now no-ops in Bluebook — gates live in Hecksagon
        port :guest do
          allow :find, :all, :where, :first, :last, :count
        end

        port :admin do
          allow :find, :all, :where, :first, :last, :count
          allow :create, :update, :destroy, :save
        end

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  let(:hecksagon) do
    Hecks.hecksagon do
      gate "Pizza", :guest do
        allow :find, :all, :where, :first, :last, :count
      end

      gate "Pizza", :admin do
        allow :find, :all, :where, :first, :last, :count
        allow :create, :update, :destroy, :save
      end
    end
  end

  describe "Hecksagon DSL" do
    it "defines gates on the hecksagon" do
      expect(hecksagon.gates.size).to eq(2)
      expect(hecksagon.gates.map(&:role)).to contain_exactly(:guest, :admin)
    end

    it "stores allowed methods on each gate" do
      guest = hecksagon.gate_for("Pizza", :guest)
      expect(guest).to be_a(Hecksagon::Structure::GateDefinition)
      expect(guest.allowed_methods).to include(:find, :all, :where)
      expect(guest.allowed_methods).not_to include(:create, :destroy)
    end
  end

  describe "Application without port (backward compatible)" do
    let!(:app) { Hecks.load(domain) }

    it "allows all methods" do
      pizza = PortTestDomain::Pizza.create(name: "Margherita")
      expect(pizza.name).to eq("Margherita")
      expect(PortTestDomain::Pizza.all.size).to eq(1)
      expect(PortTestDomain::Pizza.find(pizza.id)).not_to be_nil
      expect(PortTestDomain::Pizza.count).to eq(1)
    end
  end

  # Gate enforcement via Hecksagon will be wired in Phase 3 of HEC-390.
  # These tests verify the Hecksagon IR is correct; runtime enforcement
  # will be added when GateEnforcer replaces PortEnforcer.

  describe "GateDefinition#allows?" do
    it "returns true for allowed methods" do
      gate = Hecksagon::Structure::GateDefinition.new(aggregate: "Pizza", role: :test, allowed_methods: [:find, :all])
      expect(gate.allows?(:find)).to be true
      expect(gate.allows?("all")).to be true
    end

    it "returns false for disallowed methods" do
      gate = Hecksagon::Structure::GateDefinition.new(aggregate: "Pizza", role: :test, allowed_methods: [:find])
      expect(gate.allows?(:create)).to be false
    end
  end

  describe "PortDefinition#allows? (legacy)" do
    it "returns true for allowed methods" do
      port = Hecks::DomainModel::Structure::PortDefinition.new(name: :test, allowed_methods: [:find, :all])
      expect(port.allows?(:find)).to be true
      expect(port.allows?("all")).to be true
    end

    it "returns false for disallowed methods" do
      port = Hecks::DomainModel::Structure::PortDefinition.new(name: :test, allowed_methods: [:find])
      expect(port.allows?(:create)).to be false
    end
  end
end

require "spec_helper"

RSpec.describe "Port Authorization" do
  let(:domain) do
    Hecks.domain "PortTest" do
      aggregate "Pizza" do
        attribute :name, String

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

  describe "DSL" do
    it "defines ports on the aggregate" do
      agg = domain.aggregates.first
      expect(agg.ports).to be_a(Hash)
      expect(agg.ports.keys).to contain_exactly(:guest, :admin)
    end

    it "stores allowed methods on each port" do
      agg = domain.aggregates.first
      guest = agg.ports[:guest]
      expect(guest).to be_a(Hecks::DomainModel::Structure::PortDefinition)
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

  describe "Application with :admin port" do
    let!(:app) { Hecks.load(domain, port: :admin) }

    it "allows read methods" do
      expect { PortTestDomain::Pizza.all }.not_to raise_error
      expect { PortTestDomain::Pizza.count }.not_to raise_error
      expect { PortTestDomain::Pizza.first }.not_to raise_error
      expect { PortTestDomain::Pizza.last }.not_to raise_error
      # where is opt-in via AdHocQueries.bind
    end

    it "allows write methods" do
      pizza = PortTestDomain::Pizza.create(name: "Pepperoni")
      expect(pizza.name).to eq("Pepperoni")
    end

    it "allows instance save" do
      pizza = PortTestDomain::Pizza.create(name: "Hawaiian")
      expect { pizza.save }.not_to raise_error
    end

    it "allows instance update" do
      pizza = PortTestDomain::Pizza.create(name: "Veggie")
      expect { pizza.update(name: "SuperVeggie") }.not_to raise_error
    end

    it "allows instance destroy" do
      pizza = PortTestDomain::Pizza.create(name: "Temp")
      expect { pizza.destroy }.not_to raise_error
    end
  end

  describe "Application with :guest port" do
    let!(:app) { Hecks.load(domain, port: :guest) }

    it "allows read methods" do
      expect { PortTestDomain::Pizza.all }.not_to raise_error
      expect { PortTestDomain::Pizza.count }.not_to raise_error
      expect { PortTestDomain::Pizza.first }.not_to raise_error
      expect { PortTestDomain::Pizza.last }.not_to raise_error
      # where is opt-in via AdHocQueries.bind
    end

    it "raises PortAccessDenied for create" do
      expect { PortTestDomain::Pizza.create(name: "Nope") }.to raise_error(
        Hecks::PortAccessDenied, /Pizza\.create.*:guest/
      )
    end

    it "raises PortAccessDenied for instance save" do
      # Build an instance manually (without going through create)
      instance = PortTestDomain::Pizza.new(name: "Sneaky")
      expect { instance.save }.to raise_error(
        Hecks::PortAccessDenied, /Pizza#save.*:guest/
      )
    end

    it "raises PortAccessDenied for instance destroy" do
      instance = PortTestDomain::Pizza.new(name: "Sneaky")
      expect { instance.destroy }.to raise_error(
        Hecks::PortAccessDenied, /Pizza#destroy.*:guest/
      )
    end

    it "raises PortAccessDenied for instance update" do
      instance = PortTestDomain::Pizza.new(name: "Sneaky")
      expect { instance.update(name: "Nope") }.to raise_error(
        Hecks::PortAccessDenied, /Pizza#update.*:guest/
      )
    end

    it "raises PortAccessDenied for delete" do
      expect { PortTestDomain::Pizza.delete("some-id") }.to raise_error(
        Hecks::PortAccessDenied, /Pizza\.delete.*:guest/
      )
    end
  end

  describe "PortDefinition#allows?" do
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

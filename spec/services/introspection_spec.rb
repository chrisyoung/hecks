require "spec_helper"

RSpec.describe Hecks::Services::Introspection do
  let(:domain) do
    Hecks.domain "Inspect" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :label, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end

        query "Classics" do
          where(style: "Classic")
        end

        validation :name, presence: true

        invariant "name can't be blank" do
          !name.empty?
        end

        policy "NotifyKitchen" do
          on "CreatedPizza"
          trigger "CreatePizza"
        end
      end
    end
  end

  let!(:app) { Hecks.load(domain, force: true) }

  describe ".domain_def" do
    it "returns the aggregate IR" do
      expect(InspectDomain::Pizza.domain_def).to be_a(Hecks::DomainModel::Structure::Aggregate)
      expect(InspectDomain::Pizza.domain_def.name).to eq("Pizza")
    end
  end

  describe ".domain_attributes" do
    it "returns attribute names as symbols" do
      expect(InspectDomain::Pizza.domain_attributes).to eq([:name, :style, :toppings])
    end
  end

  describe ".domain_commands" do
    it "returns formatted command strings" do
      cmds = InspectDomain::Pizza.domain_commands
      expect(cmds.size).to eq(1)
      expect(cmds[0]).to include("CreatePizza")
      expect(cmds[0]).to include("CreatedPizza")
    end
  end

  describe ".domain_queries" do
    it "returns query names" do
      expect(InspectDomain::Pizza.domain_queries).to eq(["Classics"])
    end
  end

  describe ".domain_value_objects" do
    it "returns formatted value object strings" do
      vos = InspectDomain::Pizza.domain_value_objects
      expect(vos.size).to eq(1)
      expect(vos[0]).to include("Topping")
      expect(vos[0]).to include("label: String")
    end
  end

  describe ".domain_policies" do
    it "returns formatted policy strings" do
      pols = InspectDomain::Pizza.domain_policies
      expect(pols.size).to eq(1)
      expect(pols[0]).to include("NotifyKitchen")
      expect(pols[0]).to include("CreatedPizza -> CreatePizza")
    end
  end

  describe ".describe" do
    it "prints a formatted summary" do
      expect { InspectDomain::Pizza.describe }.to output(/Pizza/).to_stdout
      expect { InspectDomain::Pizza.describe }.to output(/Attributes:/).to_stdout
      expect { InspectDomain::Pizza.describe }.to output(/Commands:/).to_stdout
      expect { InspectDomain::Pizza.describe }.to output(/Queries:/).to_stdout
      expect { InspectDomain::Pizza.describe }.to output(/Policies:/).to_stdout
    end
  end

  describe "Domain#describe" do
    it "prints a domain-level summary" do
      expect { domain.describe }.to output(/Inspect/).to_stdout
      expect { domain.describe }.to output(/Pizza/).to_stdout
      expect { domain.describe }.to output(/CreatePizza/).to_stdout
    end
  end
end

require "spec_helper"

RSpec.describe Hecks::DSL::DomainBuilder do
  describe "aggregates" do
    it "builds domain with name and aggregates" do
      domain = Hecks.domain("Pizzas") { aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } } }
      expect(domain.name).to eq("Pizzas")
      expect(domain.aggregates.size).to eq(1)
      expect(domain.aggregates.first.name).to eq("Pizza")
      expect(domain.aggregates.first.attributes.first.name).to eq(:name)
      expect(domain.aggregates.first.attributes.first.type).to eq(String)
    end

    it "builds multiple aggregates" do
      domain = Hecks.domain("Inventory") do
        aggregate("Widget") { attribute :name, String; command("CreateWidget") { attribute :name, String } }
        aggregate("Gadget") { attribute :count, Integer; command("CreateGadget") { attribute :count, Integer } }
      end
      expect(domain.aggregates.map(&:name)).to eq(["Widget", "Gadget"])
    end
  end

  describe "commands and events" do
    it "infers past-tense event names" do
      domain = Hecks.domain("Pizzeria") { aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String }; command("DeletePizza") { attribute :id, String } } }
      expect(domain.aggregates.first.events.map(&:name)).to eq(["CreatedPizza", "DeletedPizza"])
    end

    it "copies command and aggregate attributes to inferred event" do
      domain = Hecks.domain("Pizzeria") { aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :title, String; attribute :price, Float } } }
      event = domain.aggregates.first.events.first
      expect(event.attributes.map(&:name)).to eq([:aggregate_id, :title, :price, :name])
    end
  end

  describe "queries" do
    it "stores query name and block" do
      domain = Hecks.domain("Devices") { aggregate("Device") { attribute :status, String; command("CreateDevice") { attribute :status, String }; query("Active") { where(status: "on") } } }
      q = domain.aggregates.first.queries.first
      expect(q.name).to eq("Active")
      expect(q.block).to be_a(Proc)
    end

    it "stores parameterized query blocks" do
      domain = Hecks.domain("Devices") { aggregate("Device") { attribute :status, String; command("CreateDevice") { attribute :status, String }; query("ByStatus") { |status| where(status: status) } } }
      q = domain.aggregates.first.queries.first
      expect(q.block.parameters).to eq([[:opt, :status]])
    end
  end

  describe "value objects" do
    it "stores VOs with attributes and invariants" do
      domain = Hecks.domain("Orders") do
        aggregate("Order") do
          attribute :items, list_of("Item")
          value_object("Item") { attribute :qty, Integer; invariant("must be positive") { qty > 0 } }
          command("CreateOrder") { attribute :name, String }
        end
      end
      vo = domain.aggregates.first.value_objects.first
      expect(vo.name).to eq("Item")
      expect(vo.attributes.first.name).to eq(:qty)
      expect(vo.invariants.size).to eq(1)
      expect(vo.invariants.first.message).to eq("must be positive")
    end
  end

  describe "policies" do
    it "stores event and trigger command" do
      domain = Hecks.domain("Workflow") do
        aggregate("Task") { attribute :name, String; command("CreateTask") { attribute :name, String }; command("ProcessTask") { attribute :name, String }; policy("React") { on "CreatedTask"; trigger "ProcessTask" } }
      end
      pol = domain.aggregates.first.policies.first
      expect(pol.name).to eq("React")
      expect(pol.event_name).to eq("CreatedTask")
      expect(pol.trigger_command).to eq("ProcessTask")
    end
  end

  describe "validations" do
    it "stores field and rules" do
      domain = Hecks.domain("Pizzeria") { aggregate("Pizza") { attribute :name, String; validation(:name, presence: true); command("CreatePizza") { attribute :name, String } } }
      val = domain.aggregates.first.validations.first
      expect(val.field).to eq(:name)
      expect(val.presence?).to be true
    end
  end

  describe "scopes" do
    it "stores hash scopes" do
      domain = Hecks.domain("Devices") { aggregate("Device") { attribute :status, String; command("CreateDevice") { attribute :status, String }; scope(:active, status: "on") } }
      scope = domain.aggregates.first.scopes.first
      expect(scope.name).to eq(:active)
      expect(scope.callable?).to be false
    end

    it "stores lambda scopes" do
      domain = Hecks.domain("Devices") { aggregate("Device") { attribute :status, String; command("CreateDevice") { attribute :status, String }; scope(:by_status, ->(val) { { status: val } }) } }
      scope = domain.aggregates.first.scopes.first
      expect(scope.callable?).to be true
      expect(scope.conditions.call("x")).to eq({ status: "x" })
    end
  end

  describe "attribute types" do
    it "supports String, Integer, Float" do
      domain = Hecks.domain("Types") { aggregate("Widget") { attribute :label, String; attribute :count, Integer; attribute :price, Float; command("CreateWidget") { attribute :label, String } } }
      types = domain.aggregates.first.attributes.map(&:type)
      expect(types).to eq([String, Integer, Float])
    end

    it "supports JSON" do
      domain = Hecks.domain("Types") { aggregate("Widget") { attribute :data, JSON; command("CreateWidget") { attribute :data, JSON } } }
      expect(domain.aggregates.first.attributes.first.json?).to be true
    end

    it "supports reference_to" do
      domain = Hecks.domain("Types") do
        aggregate("Widget") { attribute :name, String; command("CreateWidget") { attribute :name, String } }
        aggregate("Part") { attribute :widget_id, reference_to("Widget"); command("CreatePart") { attribute :widget_id, reference_to("Widget") } }
      end
      attr = domain.aggregates.last.attributes.first
      expect(attr.reference?).to be true
      expect(attr.type.to_s).to eq("Widget")
    end

    it "supports list_of" do
      domain = Hecks.domain("Types") { aggregate("Widget") { attribute :items, list_of("Item"); command("CreateWidget") { attribute :name, String } } }
      attr = domain.aggregates.first.attributes.first
      expect(attr.list?).to be true
    end
  end

  describe "domain metadata" do
    it "generates gem_name from domain name" do
      expect(Hecks.domain("Pizza Shop") { aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } } }.gem_name).to eq("pizza_shop_domain")
    end

    it "generates module_name from domain name" do
      expect(Hecks.domain("Pizza Shop") { aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } } }.module_name).to eq("PizzaShop")
    end

    it "source_path is settable" do
      domain = Hecks.domain("Metadata") { aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } } }
      domain.source_path = "/tmp/test.rb"
      expect(domain.source_path).to eq("/tmp/test.rb")
    end
  end

  describe "compositions" do
    it "stores composes declarations on the aggregate" do
      domain = Hecks.domain("Shop") do
        aggregate("Pizza") do
          composes "Topping"
          composes "Sauce", as: :base_sauce
          attribute :name, String
          command("CreatePizza") { attribute :name, String }
        end
      end
      comps = domain.aggregates.first.compositions
      expect(comps.length).to eq(2)
      expect(comps[0]).to eq({ name: :topping, type: "Topping" })
      expect(comps[1]).to eq({ name: :base_sauce, type: "Sauce" })
    end
  end

  describe "domain-level actors" do
    it "stores actors on the domain" do
      domain = Hecks.domain("Gov") do
        actor "governance_board"
        actor "admin", description: "System administrator"
        aggregate("Policy") { attribute :name, String; command("CreatePolicy") { attribute :name, String } }
      end
      expect(domain.actors.length).to eq(2)
      expect(domain.actors[0]).to eq({ name: "governance_board", description: nil })
      expect(domain.actors[1]).to eq({ name: "admin", description: "System administrator" })
    end
  end

  describe "reference classification" do
    it "classifies local entity/VO references as composition" do
      domain = Hecks.domain("Shop") do
        aggregate("Order") do
          attribute :name, String
          entity("LineItem") { attribute :qty, Integer }
          reference_to "LineItem"
          command("CreateOrder") { attribute :name, String }
        end
      end
      ref = domain.aggregates.first.references.find { |r| r[:type] == "LineItem" }
      expect(ref[:kind]).to eq(:composition)
    end

    it "classifies aggregate root references as aggregation" do
      domain = Hecks.domain("Shop") do
        aggregate("Order") do
          attribute :name, String
          reference_to "Customer"
          command("CreateOrder") { attribute :name, String }
        end
        aggregate("Customer") { attribute :name, String; command("CreateCustomer") { attribute :name, String } }
      end
      ref = domain.aggregates.first.references.find { |r| r[:type] == "Customer" }
      expect(ref[:kind]).to eq(:aggregation)
    end

    it "classifies :: paths as cross-context" do
      domain = Hecks.domain("Shop") do
        aggregate("Order") do
          attribute :name, String
          reference_to "Billing::Invoice"
          command("CreateOrder") { attribute :name, String }
        end
      end
      ref = domain.aggregates.first.references.find { |r| r[:type] == "Invoice" }
      expect(ref[:kind]).to eq(:cross_context)
      expect(ref[:domain]).to eq("Billing")
    end
  end

  describe "explicit domain events" do
    it "includes explicit events alongside inferred ones" do
      domain = Hecks.domain("Gov") do
        aggregate("Policy") do
          attribute :name, String
          event("PolicyExpired") { attribute :policy_id, String }
          command("CreatePolicy") { attribute :name, String }
        end
      end
      events = domain.aggregates.first.events.map(&:name)
      expect(events).to include("CreatedPolicy")
      expect(events).to include("PolicyExpired")
    end

    it "explicit event overrides inferred event with same name" do
      domain = Hecks.domain("Gov") do
        aggregate("Policy") do
          attribute :name, String
          event("CreatedPolicy") { attribute :custom_field, String }
          command("CreatePolicy") { attribute :name, String }
        end
      end
      event = domain.aggregates.first.events.find { |e| e.name == "CreatedPolicy" }
      expect(event.attributes.map(&:name)).to include(:custom_field)
    end
  end
end

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
      domain = Hecks.domain("T") do
        aggregate("A") { attribute :n, String; command("CreateA") { attribute :n, String } }
        aggregate("B") { attribute :x, Integer; command("CreateB") { attribute :x, Integer } }
      end
      expect(domain.aggregates.map(&:name)).to eq(["A", "B"])
    end
  end

  describe "commands and events" do
    it "infers past-tense event names" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :n, String; command("CreatePizza") { attribute :n, String }; command("DeletePizza") { attribute :id, String } } }
      expect(domain.aggregates.first.events.map(&:name)).to eq(["CreatedPizza", "DeletedPizza"])
    end

    it "copies command attributes to inferred event" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :n, String; command("CreateP") { attribute :name, String; attribute :price, Float } } }
      event = domain.aggregates.first.events.first
      expect(event.attributes.map(&:name)).to eq([:name, :price])
      expect(event.attributes.map(&:type)).to eq([String, Float])
    end
  end

  describe "queries" do
    it "stores query name and block" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :s, String; command("CreateP") { attribute :s, String }; query("Active") { where(s: "on") } } }
      q = domain.aggregates.first.queries.first
      expect(q.name).to eq("Active")
      expect(q.block).to be_a(Proc)
    end

    it "stores parameterized query blocks" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :s, String; command("CreateP") { attribute :s, String }; query("ByS") { |s| where(s: s) } } }
      q = domain.aggregates.first.queries.first
      expect(q.block.parameters).to eq([[:opt, :s]])
    end
  end

  describe "value objects" do
    it "stores VOs with attributes and invariants" do
      domain = Hecks.domain("T") do
        aggregate("P") do
          attribute :items, list_of("Item")
          value_object("Item") { attribute :qty, Integer; invariant("must be positive") { qty > 0 } }
          command("CreateP") { attribute :n, String }
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
      domain = Hecks.domain("T") do
        aggregate("A") { attribute :n, String; command("CreateA") { attribute :n, String }; command("DoB") { attribute :n, String }; policy("React") { on "CreatedA"; trigger "DoB" } }
      end
      pol = domain.aggregates.first.policies.first
      expect(pol.name).to eq("React")
      expect(pol.event_name).to eq("CreatedA")
      expect(pol.trigger_command).to eq("DoB")
    end
  end

  describe "validations" do
    it "stores field and rules" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :n, String; validation(:n, presence: true); command("CreateP") { attribute :n, String } } }
      val = domain.aggregates.first.validations.first
      expect(val.field).to eq(:n)
      expect(val.presence?).to be true
    end
  end

  describe "scopes" do
    it "stores hash scopes" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :s, String; command("CreateP") { attribute :s, String }; scope(:active, s: "on") } }
      scope = domain.aggregates.first.scopes.first
      expect(scope.name).to eq(:active)
      expect(scope.callable?).to be false
    end

    it "stores lambda scopes" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :s, String; command("CreateP") { attribute :s, String }; scope(:by_s, ->(v) { { s: v } }) } }
      scope = domain.aggregates.first.scopes.first
      expect(scope.callable?).to be true
      expect(scope.conditions.call("x")).to eq({ s: "x" })
    end
  end

  describe "attribute types" do
    it "supports String, Integer, Float" do
      domain = Hecks.domain("T") { aggregate("A") { attribute :a, String; attribute :b, Integer; attribute :c, Float; command("CreateA") { attribute :a, String } } }
      types = domain.aggregates.first.attributes.map(&:type)
      expect(types).to eq([String, Integer, Float])
    end

    it "supports JSON" do
      domain = Hecks.domain("T") { aggregate("A") { attribute :data, JSON; command("CreateA") { attribute :data, JSON } } }
      expect(domain.aggregates.first.attributes.first.json?).to be true
    end

    it "supports reference_to" do
      domain = Hecks.domain("T") do
        aggregate("A") { attribute :n, String; command("CreateA") { attribute :n, String } }
        aggregate("B") { attribute :a_id, reference_to("A"); command("CreateB") { attribute :a_id, reference_to("A") } }
      end
      attr = domain.aggregates.last.attributes.first
      expect(attr.reference?).to be true
      expect(attr.type.to_s).to eq("A")
    end

    it "supports list_of" do
      domain = Hecks.domain("T") { aggregate("A") { attribute :items, list_of("Item"); command("CreateA") { attribute :n, String } } }
      attr = domain.aggregates.first.attributes.first
      expect(attr.list?).to be true
    end
  end

  describe "domain metadata" do
    it "generates gem_name from domain name" do
      expect(Hecks.domain("Pizza Shop") { aggregate("P") { attribute :n, String; command("CreateP") { attribute :n, String } } }.gem_name).to eq("pizza_shop_domain")
    end

    it "generates module_name from domain name" do
      expect(Hecks.domain("Pizza Shop") { aggregate("P") { attribute :n, String; command("CreateP") { attribute :n, String } } }.module_name).to eq("PizzaShop")
    end

    it "source_path is settable" do
      domain = Hecks.domain("T") { aggregate("P") { attribute :n, String; command("CreateP") { attribute :n, String } } }
      domain.source_path = "/tmp/test.rb"
      expect(domain.source_path).to eq("/tmp/test.rb")
    end
  end
end

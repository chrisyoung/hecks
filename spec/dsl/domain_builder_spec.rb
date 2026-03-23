require "spec_helper"

RSpec.describe Hecks::DSL::DomainBuilder do
  it "builds a domain with aggregates" do
    domain = Hecks.domain("Test") { aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } } }
    expect(domain.name).to eq("Test")
    expect(domain.aggregates.first.name).to eq("Pizza")
  end

  it "builds queries" do
    domain = Hecks.domain("T") { aggregate("P") { attribute :s, String; command("CreateP") { attribute :s, String }; query("Q") { where(s: "x") } } }
    expect(domain.aggregates.first.queries.first.name).to eq("Q")
  end

  it "builds value objects with invariants" do
    domain = Hecks.domain("T") do
      aggregate("P") do
        attribute :toppings, list_of("T")
        value_object("T") { attribute :n, String; invariant("x") { true } }
        command("CreateP") { attribute :n, String }
      end
    end
    expect(domain.aggregates.first.value_objects.first.invariants.size).to eq(1)
  end

  it "builds policies" do
    domain = Hecks.domain("T") do
      aggregate("A") do
        attribute :n, String
        command("CreateA") { attribute :n, String }
        command("DoB") { attribute :n, String }
        policy("React") { on "CreatedA"; trigger "DoB" }
      end
    end
    expect(domain.aggregates.first.policies.first.trigger_command).to eq("DoB")
  end

  it "infers events from commands" do
    domain = Hecks.domain("T") { aggregate("P") { attribute :n, String; command("CreateP") { attribute :n, String }; command("DeleteP") { attribute :id, String } } }
    expect(domain.aggregates.first.events.map(&:name)).to eq(["CreatedP", "DeletedP"])
  end

  it "supports JSON attributes" do
    domain = Hecks.domain("T") { aggregate("R") { attribute :pts, JSON; command("CreateR") { attribute :pts, JSON } } }
    expect(domain.aggregates.first.attributes.first.json?).to be true
  end

  it "generates gem_name" do
    domain = Hecks.domain("Pizza Shop") { aggregate("P") { attribute :n, String; command("CreateP") { attribute :n, String } } }
    expect(domain.gem_name).to eq("pizza_shop_domain")
  end

  it "supports scopes" do
    domain = Hecks.domain("T") { aggregate("P") { attribute :s, String; command("CreateP") { attribute :s, String }; scope(:active, s: "on") } }
    expect(domain.aggregates.first.scopes.first.name).to eq(:active)
  end

  it "supports validations" do
    domain = Hecks.domain("T") { aggregate("P") { attribute :n, String; validation(:n, presence: true); command("CreateP") { attribute :n, String } } }
    expect(domain.aggregates.first.validations.first.presence?).to be true
  end

  it "supports references" do
    domain = Hecks.domain("T") do
      aggregate("P") { attribute :n, String; command("CreateP") { attribute :n, String } }
      aggregate("O") { attribute :p_id, reference_to("P"); command("CreateO") { attribute :p_id, reference_to("P") } }
    end
    expect(domain.aggregates.last.attributes.first.reference?).to be true
  end

  it "source_path is settable" do
    domain = Hecks.domain("T") { aggregate("P") { attribute :n, String; command("CreateP") { attribute :n, String } } }
    domain.source_path = "/tmp/test.rb"
    expect(domain.source_path).to eq("/tmp/test.rb")
  end
end

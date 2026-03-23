require "spec_helper"

RSpec.describe "Validation Rules" do
  describe "Naming::CommandNaming" do
    it "accepts WordNet-known verbs" do
      domain = Hecks.domain("T") { aggregate("A") { attribute :n, String; command("ReconcileThing") { attribute :n, String } } }
      expect(Hecks::Validator.new(domain).valid?).to be true
    end

    it "rejects non-verbs" do
      domain = Hecks.domain("T") { aggregate("A") { attribute :n, String; command("PizzaData") { attribute :n, String } } }
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be false
      expect(validator.errors.first).to match(/doesn't start with a verb/)
    end

    it "suggests adding custom verbs in error message" do
      domain = Hecks.domain("T") { aggregate("A") { attribute :n, String; command("YeetThing") { attribute :n, String } } }
      validator = Hecks::Validator.new(domain)
      validator.valid?
      expect(validator.errors.first).to include("verbs.txt")
    end
  end

  describe "Naming::NameCollisions" do
    it "rejects aggregate and value object with same name" do
      domain = Hecks.domain("T") do
        aggregate("Pizza") do
          attribute :name, String
          value_object("Pizza") { attribute :x, String }
          command("CreatePizza") { attribute :name, String }
        end
      end
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be false
    end
  end

  describe "References::NoSelfReferences" do
    it "rejects self-referencing aggregates" do
      domain = Hecks.domain("T") do
        aggregate("Thing") do
          attribute :thing_id, reference_to("Thing")
          command("CreateThing") { attribute :name, String }
        end
      end
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be false
    end
  end

  describe "References::NoBidirectionalReferences" do
    it "rejects bidirectional references" do
      domain = Hecks.domain("T") do
        aggregate("Pizza") do
          attribute :order_id, reference_to("Order")
          command("CreatePizza") { attribute :name, String }
        end
        aggregate("Order") do
          attribute :pizza_id, reference_to("Pizza")
          command("PlaceOrder") { attribute :pizza_id, reference_to("Pizza") }
        end
      end
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be false
    end
  end

  describe "References::NoValueObjectReferences" do
    it "rejects references in value objects" do
      domain = Hecks.domain("T") do
        aggregate("Pizza") do
          attribute :name, String
          value_object("Topping") { attribute :order_id, reference_to("Order") }
          command("CreatePizza") { attribute :name, String }
        end
        aggregate("Order") do
          attribute :qty, Integer
          command("PlaceOrder") { attribute :qty, Integer }
        end
      end
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be false
    end
  end

  describe "Structure::AggregatesHaveCommands" do
    it "warns when aggregate has no commands" do
      domain = Hecks.domain("T") { aggregate("Thing") { attribute :name, String } }
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be false
    end
  end

  describe "Structure::ValidPolicyTriggers" do
    it "rejects policies triggering nonexistent commands" do
      domain = Hecks.domain("T") do
        aggregate("A") do
          attribute :n, String
          command("CreateA") { attribute :n, String }
          policy("React") { on "CreatedA"; trigger "Nonexistent" }
        end
      end
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be false
      expect(validator.errors.first).to match(/unknown command/i)
    end
  end

  describe "Structure::ValidPolicyEvents" do
    it "allows cross-domain events (warning, not error)" do
      domain = Hecks.domain("T") do
        aggregate("A") do
          attribute :n, String
          command("CreateA") { attribute :n, String }
          policy("React") { on "ExternalEvent"; trigger "CreateA" }
        end
      end
      validator = Hecks::Validator.new(domain)
      expect(validator.valid?).to be true
    end
  end
end

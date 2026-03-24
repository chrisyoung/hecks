require "spec_helper"

RSpec.describe Hecks::Session::AggregateHandle do
  let(:session) { Hecks::Session.new("Pizzas") }

  before { allow($stdout).to receive(:puts) }

  describe "getting a handle" do
    it "returns a handle from session.aggregate" do
      pizza = session.aggregate("Pizza")
      expect(pizza).to be_a(described_class)
    end

    it "returns the same handle on repeated calls" do
      a = session.aggregate("Pizza")
      b = session.aggregate("Pizza")
      expect(a).to equal(b)
    end
  end

  describe "#add_attribute" do
    it "adds an attribute" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String

      expect(pizza.attributes).to eq([:name])
    end

    it "supports list_of" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :toppings, pizza.list_of("Topping")

      domain = session.to_domain
      attr = domain.aggregates.first.attributes.first
      expect(attr).to be_list
    end

    it "supports reference_to" do
      session.aggregate("Pizza")
      order = session.aggregate("Order")
      order.add_attribute :pizza_id, order.reference_to("Pizza")

      domain = session.to_domain
      order_agg = domain.aggregates.find { |a| a.name == "Order" }
      attr = order_agg.attributes.first
      expect(attr).to be_reference
    end

    it "returns self for chaining" do
      pizza = session.aggregate("Pizza")
      result = pizza.add_attribute(:name, String)
      expect(result).to equal(pizza)
    end
  end

  describe "#remove_attribute" do
    it "removes an attribute" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String
      pizza.add_attribute :description, String
      pizza.remove_attribute :description

      expect(pizza.attributes).to eq([:name])
    end
  end

  describe "#add_value_object" do
    it "adds a value object" do
      pizza = session.aggregate("Pizza")
      pizza.add_value_object "Topping" do
        attribute :name, String
        attribute :amount, Integer
      end

      expect(pizza.value_objects).to eq(["Topping"])
    end
  end

  describe "#add_command" do
    it "adds a command and infers an event" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String
      pizza.add_command "CreatePizza" do
        attribute :name, String
      end

      expect(pizza.commands).to eq(["CreatePizza"])

      domain = session.to_domain
      events = domain.aggregates.first.events
      expect(events.map(&:name)).to eq(["CreatedPizza"])
    end
  end

  describe "#add_validation" do
    it "adds a validation" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String
      pizza.add_validation :name, presence: true

      domain = session.to_domain
      agg = domain.aggregates.first
      expect(agg.validations.size).to eq(1)
    end
  end

  describe "#add_policy" do
    it "adds a policy" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String
      pizza.add_command("CreatePizza") { attribute :name, String }
      pizza.add_policy "NotifyChef" do
        on "CreatedPizza"
        trigger "SendNotification"
      end

      domain = session.to_domain
      agg = domain.aggregates.first
      expect(agg.policies.size).to eq(1)
      expect(agg.policies.first.name).to eq("NotifyChef")
    end
  end

  describe "#describe" do
    it "prints a detailed summary" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String
      pizza.add_attribute :toppings, pizza.list_of("Topping")
      pizza.add_value_object("Topping") do
        attribute :name, String
        attribute :amount, Integer
      end
      pizza.add_validation :name, presence: true
      pizza.add_command("CreatePizza") { attribute :name, String }

      expect { pizza.describe }.to output(
        /Pizza.*Attributes:.*name: String.*toppings: list_of\(Topping\).*Value Objects:.*Topping.*Commands:.*CreatePizza.*CreatedPizza.*Validations:.*name: presence/m
      ).to_stdout
    end
  end

  describe "#preview" do
    it "prints the generated code" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String

      expect { pizza.preview }.to output(/module PizzasDomain.*class Pizza.*include Hecks::Model.*attribute :name/m).to_stdout
    end
  end

  describe "#inspect" do
    it "shows a readable summary" do
      pizza = session.aggregate("Pizza")
      pizza.add_attribute :name, String
      pizza.add_command("CreatePizza") { attribute :name, String }

      expect(pizza.inspect).to eq("#<Pizza (1 attributes, 1 commands)>")
    end
  end

  describe "short method names" do
    it "attribute is an alias for add_attribute" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, String
      expect(pizza.attributes).to eq([:name])
    end

    it "command is an alias for add_command" do
      pizza = session.aggregate("Pizza")
      pizza.command("CreatePizza") { attribute :name, String }
      expect(pizza.commands).to eq(["CreatePizza"])
    end

    it "validation is an alias for add_validation" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, String
      pizza.validation :name, presence: true
      domain = session.to_domain
      expect(domain.aggregates.first.validations.size).to eq(1)
    end

    it "value_object is an alias for add_value_object" do
      pizza = session.aggregate("Pizza")
      pizza.value_object("Topping") { attribute :name, String }
      expect(pizza.value_objects).to eq(["Topping"])
    end

    it "policy is an alias for add_policy" do
      pizza = session.aggregate("Pizza")
      pizza.command("CreatePizza") { attribute :name, String }
      pizza.policy("NotifyChef") { on "CreatedPizza"; trigger "SendNotification" }
      domain = session.to_domain
      expect(domain.aggregates.first.policies.size).to eq(1)
    end

    it "remove is an alias for remove_attribute" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, String
      pizza.attribute :desc, String
      pizza.remove :desc
      expect(pizza.attributes).to eq([:name])
    end
  end

  describe "name normalization" do
    it "normalizes lowercase aggregate names" do
      cat = session.aggregate("cat")
      expect(cat.name).to eq("Cat")
    end

    it "normalizes lowercase command names" do
      pizza = session.aggregate("Pizza")
      pizza.command("create pizza") { attribute :name, String }
      expect(pizza.commands).to eq(["CreatePizza"])
    end

    it "normalizes lowercase value object names" do
      pizza = session.aggregate("Pizza")
      pizza.value_object("topping") { attribute :name, String }
      expect(pizza.value_objects).to eq(["Topping"])
    end

    it "normalizes lowercase policy names" do
      pizza = session.aggregate("Pizza")
      pizza.command("CreatePizza") { attribute :name, String }
      pizza.policy("notify chef") { on "CreatedPizza"; trigger "SendNotification" }
      domain = session.to_domain
      expect(domain.aggregates.first.policies.first.name).to eq("NotifyChef")
    end
  end

  describe "type inference" do
    it "defaults type to String" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(String)
    end

    it "resolves :string to String" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, :string
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(String)
    end

    it "resolves :integer to Integer" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :count, :integer
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(Integer)
    end

    it "resolves :boolean to TrueClass" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :active, :boolean
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(TrueClass)
    end
  end

  describe "#valid?" do
    it "returns false when aggregate has no commands" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, String
      expect(pizza.valid?).to be false
    end

    it "returns true when aggregate is valid" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      expect(pizza.valid?).to be true
    end
  end

  describe "#errors" do
    it "returns errors for invalid aggregate" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, String
      expect(pizza.errors).to include(/Pizza has no commands/)
    end

    it "returns empty array for valid aggregate" do
      pizza = session.aggregate("Pizza")
      pizza.attribute :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      expect(pizza.errors).to be_empty
    end
  end


  describe "#verb" do
    it "adds a custom verb to the session" do
      pizza = session.aggregate("Pizza")
      pizza.verb("Poop")
      domain = session.to_domain
      expect(domain.custom_verbs).to include("Poop")
    end
  end
end

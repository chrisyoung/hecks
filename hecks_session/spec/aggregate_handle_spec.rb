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

  describe "#attr" do
    it "adds an attribute" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String

      expect(pizza.attributes).to eq([:name])
    end

    it "supports list_of" do
      pizza = session.aggregate("Pizza")
      pizza.attr :toppings, pizza.list_of("Topping")

      domain = session.to_domain
      attr = domain.aggregates.first.attributes.first
      expect(attr).to be_list
    end

    it "supports reference_to" do
      session.aggregate("Pizza")
      order = session.aggregate("Order")
      order.attr :pizza_id, order.reference_to("Pizza")

      domain = session.to_domain
      order_agg = domain.aggregates.find { |a| a.name == "Order" }
      attr = order_agg.attributes.first
      expect(attr).to be_reference
    end

    it "returns self for chaining" do
      pizza = session.aggregate("Pizza")
      result = pizza.attr(:name, String)
      expect(result).to equal(pizza)
    end
  end

  describe "#remove" do
    it "removes an attribute" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.attr :description, String
      pizza.remove :description

      expect(pizza.attributes).to eq([:name])
    end
  end

  describe "#value_object" do
    it "adds a value object" do
      pizza = session.aggregate("Pizza")
      pizza.value_object "Topping" do
        attribute :name, String
        attribute :amount, Integer
      end

      expect(pizza.value_objects).to eq(["Topping"])
    end
  end

  describe "#command" do
    it "adds a command and infers an event" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command "CreatePizza" do
        attribute :name, String
      end

      expect(pizza.commands).to eq(["CreatePizza"])

      domain = session.to_domain
      events = domain.aggregates.first.events
      expect(events.map(&:name)).to eq(["CreatedPizza"])
    end
  end

  describe "#validation" do
    it "adds a validation" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.validation :name, presence: true

      domain = session.to_domain
      agg = domain.aggregates.first
      expect(agg.validations.size).to eq(1)
    end
  end

  describe "#policy" do
    it "adds a policy" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      pizza.policy "NotifyChef" do
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
      pizza.attr :name, String
      pizza.attr :toppings, pizza.list_of("Topping")
      pizza.value_object("Topping") do
        attribute :name, String
        attribute :amount, Integer
      end
      pizza.validation :name, presence: true
      pizza.command("CreatePizza") { attribute :name, String }

      expect { pizza.describe }.to output(
        /Pizza.*Attributes:.*name: String.*toppings: list_of\(Topping\).*Value Objects:.*Topping.*Commands:.*CreatePizza.*CreatedPizza.*Validations:.*name: presence/m
      ).to_stdout
    end
  end

  describe "#describe with queries, scopes, and subscribers" do
    it "includes queries" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      pizza.query("ByStyle") { |style| { style: style } }

      expect { pizza.describe }.to output(/Queries:.*ByStyle/m).to_stdout
    end

    it "includes scopes" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.attr :status, String
      pizza.command("CreatePizza") { attribute :name, String }
      pizza.scope(:active, status: "active")

      expect { pizza.describe }.to output(/Scopes:.*active/m).to_stdout
    end

    it "includes subscribers" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      pizza.on_event("CreatedPizza") { |e| }

      expect { pizza.describe }.to output(/Subscribers:.*on CreatedPizza/m).to_stdout
    end
  end

  describe "#preview" do
    it "prints the generated code" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String

      expect { pizza.preview }.to output(/module PizzasDomain.*class Pizza.*include Hecks::Model.*attribute :name/m).to_stdout
    end
  end

  describe "#inspect" do
    it "shows a readable summary" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command("CreatePizza") { attribute :name, String }

      expect(pizza.inspect).to eq("#<Pizza (1 attributes, 1 commands)>")
    end
  end

  describe "short method names" do
    it "attribute is an alias for attr" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      expect(pizza.attributes).to eq([:name])
    end

    it "command works" do
      pizza = session.aggregate("Pizza")
      pizza.command("CreatePizza") { attribute :name, String }
      expect(pizza.commands).to eq(["CreatePizza"])
    end

    it "validation works" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.validation :name, presence: true
      domain = session.to_domain
      expect(domain.aggregates.first.validations.size).to eq(1)
    end

    it "value_object works" do
      pizza = session.aggregate("Pizza")
      pizza.value_object("Topping") { attribute :name, String }
      expect(pizza.value_objects).to eq(["Topping"])
    end

    it "policy works" do
      pizza = session.aggregate("Pizza")
      pizza.command("CreatePizza") { attribute :name, String }
      pizza.policy("NotifyChef") { on "CreatedPizza"; trigger "SendNotification" }
      domain = session.to_domain
      expect(domain.aggregates.first.policies.size).to eq(1)
    end

    it "remove works" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.attr :desc, String
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
      pizza.attr :name
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(String)
    end

    it "resolves :string to String" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, :string
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(String)
    end

    it "resolves :integer to Integer" do
      pizza = session.aggregate("Pizza")
      pizza.attr :count, :integer
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(Integer)
    end

    it "resolves :boolean to TrueClass" do
      pizza = session.aggregate("Pizza")
      pizza.attr :active, :boolean
      domain = session.to_domain
      expect(domain.aggregates.first.attributes.first.type).to eq(TrueClass)
    end
  end

  describe "#valid?" do
    it "returns false when aggregate has no commands" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      expect(pizza.valid?).to be false
    end

    it "returns true when aggregate is valid" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      expect(pizza.valid?).to be true
    end
  end

  describe "#errors" do
    it "returns errors for invalid aggregate" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
      expect(pizza.errors).to include(/Pizza has no commands/)
    end

    it "returns empty array for valid aggregate" do
      pizza = session.aggregate("Pizza")
      pizza.attr :name, String
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

  describe "implicit dot syntax" do
    it "creates a command from a bare snake_case call" do
      pizza = session.aggregate("Pizza")
      pizza.bake
      expect(pizza.commands).to include("BakePizza")
    end

    it "adds an attribute via name + Type" do
      pizza = session.aggregate("Pizza")
      pizza.title String
      expect(pizza.attributes).to include(:title)
    end

    it "returns a CommandHandle for chained attribute additions" do
      pizza = session.aggregate("Pizza")
      handle = pizza.create
      expect(handle).to be_a(Hecks::Session::CommandHandle)
    end

    it "adds attributes to a command via CommandHandle" do
      pizza = session.aggregate("Pizza")
      cmd_handle = pizza.create
      cmd_handle.title String
      domain = session.to_domain
      cmd = domain.aggregates.first.commands.find { |c| c.name == "CreatePizza" }
      expect(cmd.attributes.map(&:name)).to include(:title)
    end

    it "does not re-create command on repeated bare calls" do
      pizza = session.aggregate("Pizza")
      pizza.create
      pizza.create
      expect(pizza.commands.count("CreatePizza")).to eq(1)
    end

    it "adds lifecycle and transitions" do
      post = session.aggregate("Post")
      post.attr :status, String
      post.lifecycle :status, default: "draft"
      post.transition "PublishPost" => "published"
      domain = session.to_domain
      agg = domain.aggregates.first
      expect(agg.lifecycle).not_to be_nil
      expect(agg.lifecycle.field).to eq(:status)
      expect(agg.lifecycle.default).to eq("draft")
      expect(agg.lifecycle.transitions).to include("PublishPost")
    end

    it "creates value objects via PascalCase + block" do
      pizza = session.aggregate("Pizza")
      pizza.Address { attribute :street, String }
      expect(pizza.value_objects).to include("Address")
    end

    it "creates commands via snake_case + block" do
      pizza = session.aggregate("Pizza")
      pizza.bake { attribute :temp, Integer }
      domain = session.to_domain
      cmd = domain.aggregates.first.commands.find { |c| c.name == "BakePizza" }
      expect(cmd.attributes.map(&:name)).to include(:temp)
    end

    it "adds reference attributes via hash type" do
      session.aggregate("Order")
      pizza = session.aggregate("Pizza")
      pizza.order_id({ reference: "Order" })
      expect(pizza.attributes).to include(:order_id)
    end
  end
end

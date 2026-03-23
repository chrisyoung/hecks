require "spec_helper"
require "active_hecks"
require "tmpdir"

RSpec.describe ActiveHecks do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  before(:all) do
    domain = Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end

    Hecks.load_domain(domain)
    ActiveHecks.activate(PizzasDomain, domain: domain)
  end

  describe ".activate" do
    it "adds ActiveModel::Naming to aggregates" do
      expect(PizzasDomain::Pizza).to respond_to(:model_name)
    end

    it "adds ActiveModel::Naming to value objects" do
      expect(PizzasDomain::Pizza::Topping).to respond_to(:model_name)
    end

    it "does not hoist constants (Application does that)" do
      # Hoisting is the responsibility of Hecks::Services::Application
      expect(PizzasDomain::Pizza).to respond_to(:model_name)
    end
  end

  describe "aggregate (Pizza)" do
    subject(:pizza) { PizzasDomain::Pizza.new(name: "Margherita") }

    describe "model_name" do
      it "returns a valid ActiveModel::Name" do
        expect(PizzasDomain::Pizza.model_name).to be_a(ActiveModel::Name)
        expect(PizzasDomain::Pizza.model_name.singular).to eq("pizza")
        expect(PizzasDomain::Pizza.model_name.plural).to eq("pizzas")
      end
    end

    describe "#to_param" do
      it "returns the id" do
        expect(pizza.to_param).to eq(pizza.id)
      end
    end

    describe "#to_key" do
      it "returns [id] when persisted" do
        expect(pizza.to_key).to eq([pizza.id])
      end
    end

    describe "#persisted?" do
      it "returns true when id is present" do
        expect(pizza).to be_persisted
      end
    end

    describe "#new_record?" do
      it "returns false when persisted" do
        expect(pizza).not_to be_new_record
      end
    end

    describe "#to_model" do
      it "returns self" do
        expect(pizza.to_model).to equal(pizza)
      end
    end

    describe "#errors" do
      it "returns an ActiveModel::Errors" do
        expect(pizza.errors).to be_a(ActiveModel::Errors)
      end

      it "starts empty" do
        expect(pizza.errors).to be_empty
      end
    end

    describe "#attributes" do
      it "returns a hash of attributes" do
        attrs = pizza.attributes
        expect(attrs["name"]).to eq("Margherita")
        expect(attrs).to have_key("id")
      end
    end

    describe "#serializable_hash" do
      it "returns a serializable hash" do
        hash = pizza.serializable_hash
        expect(hash["name"]).to eq("Margherita")
      end
    end

    describe "#as_json" do
      it "returns a JSON-compatible hash" do
        json = pizza.as_json
        expect(json["name"]).to eq("Margherita")
        expect(json).to have_key("id")
      end

      it "supports :only option" do
        json = pizza.as_json(only: ["name"])
        expect(json.keys).to eq(["name"])
      end

      it "supports :except option" do
        json = pizza.as_json(except: ["id"])
        expect(json).not_to have_key("id")
        expect(json["name"]).to eq("Margherita")
      end
    end

    describe "#to_partial_path" do
      it "returns a partial path" do
        expect(pizza.to_partial_path).to include("pizza")
      end
    end

    describe "#valid?" do
      it "returns true for valid objects" do
        expect(pizza).to be_valid
      end

      it "returns false when presence validation fails" do
        blank_pizza = PizzasDomain::Pizza.new(name: "")
        expect(blank_pizza).not_to be_valid
      end

      it "returns false when name is nil" do
        nil_pizza = PizzasDomain::Pizza.new(name: nil)
        expect(nil_pizza).not_to be_valid
      end
    end

    describe "#invalid?" do
      it "returns true for invalid objects" do
        blank_pizza = PizzasDomain::Pizza.new(name: "")
        expect(blank_pizza).to be_invalid
      end
    end

    describe "validation errors" do
      it "populates errors after validation fails" do
        blank_pizza = PizzasDomain::Pizza.new(name: "")
        blank_pizza.valid?
        expect(blank_pizza.errors[:name]).to include("can't be blank")
      end

      it "clears errors when revalidated" do
        p = PizzasDomain::Pizza.new(name: "Margherita")
        p.valid?
        expect(p.errors).to be_empty
      end
    end

    describe ".validates" do
      it "is available as a class method" do
        expect(PizzasDomain::Pizza).to respond_to(:validates)
      end
    end

    describe "callbacks" do
      it "responds to before_save" do
        expect(PizzasDomain::Pizza).to respond_to(:before_save)
      end

      it "responds to after_save" do
        expect(PizzasDomain::Pizza).to respond_to(:after_save)
      end

      it "responds to before_create" do
        expect(PizzasDomain::Pizza).to respond_to(:before_create)
      end

      it "responds to before_destroy" do
        expect(PizzasDomain::Pizza).to respond_to(:before_destroy)
      end

      it "responds to before_update" do
        expect(PizzasDomain::Pizza).to respond_to(:before_update)
      end
    end
  end

  describe "aggregate with persistence" do
    before(:all) do
      domain = Hecks.domain "Bakery" do
        aggregate "Bread" do
          attribute :name, String
          validation :name, presence: true

          command "CreateBread" do
            attribute :name, String
          end
        end
      end

      Hecks.load_domain(domain)
      @app = Hecks::Services::Application.new(domain)
      ActiveHecks.activate(BakeryDomain)
    end

    describe "#save" do
      it "returns false when invalid" do
        bread = BakeryDomain::Bread.new(name: "")
        expect(bread.save).to eq(false)
      end

      it "returns the object when valid" do
        bread = BakeryDomain::Bread.new(name: "Sourdough")
        expect(bread.save).to eq(bread)
      end

      it "does not persist invalid objects" do
        count_before = BakeryDomain::Bread.count
        bread = BakeryDomain::Bread.new(name: "")
        bread.save
        expect(BakeryDomain::Bread.count).to eq(count_before)
      end

      it "persists valid objects" do
        count_before = BakeryDomain::Bread.count
        bread = BakeryDomain::Bread.new(name: "Rye")
        bread.save
        expect(BakeryDomain::Bread.count).to eq(count_before + 1)
      end
    end

    describe "#save!" do
      it "raises ActiveModel::ValidationError when invalid" do
        bread = BakeryDomain::Bread.new(name: "")
        expect { bread.save! }.to raise_error(ActiveModel::ValidationError)
      end

      it "saves and returns the object when valid" do
        bread = BakeryDomain::Bread.new(name: "Pumpernickel")
        expect(bread.save!).to eq(bread)
      end
    end

    describe "callback integration" do
      it "runs before_save callbacks" do
        called = false
        BakeryDomain::Bread.before_save { called = true }
        bread = BakeryDomain::Bread.new(name: "Ciabatta")
        bread.save
        expect(called).to eq(true)
      end
    end
  end

  describe "value object (Topping)" do
    subject(:topping) { PizzasDomain::Pizza::Topping.new(name: "Cheese", amount: 2) }

    describe "model_name" do
      it "returns a valid ActiveModel::Name" do
        expect(PizzasDomain::Pizza::Topping.model_name).to be_a(ActiveModel::Name)
      end
    end

    describe "#persisted?" do
      it "returns false" do
        expect(topping).not_to be_persisted
      end
    end

    describe "#to_param" do
      it "returns nil" do
        expect(topping.to_param).to be_nil
      end
    end

    describe "#to_key" do
      it "returns nil" do
        expect(topping.to_key).to be_nil
      end
    end

    describe "#attributes" do
      it "returns a hash of attributes" do
        attrs = topping.attributes
        expect(attrs["name"]).to eq("Cheese")
        expect(attrs["amount"]).to eq(2)
      end
    end

    describe "#as_json" do
      it "returns a JSON-compatible hash" do
        json = topping.as_json
        expect(json["name"]).to eq("Cheese")
        expect(json["amount"]).to eq(2)
      end
    end

    it "does not respond to valid? (frozen objects)" do
      expect(topping).not_to respond_to(:valid?)
    end
  end
end

require "spec_helper"
require "active_hecks"

RSpec.describe ActiveHecks do
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

    it "skips exception classes" do
      expect(PizzasDomain::InvariantError.ancestors).not_to include(ActiveHecks::DomainModelCompat)
      expect(PizzasDomain::ValidationError.ancestors).not_to include(ActiveHecks::DomainModelCompat)
    end
  end

  describe "DomainModelCompat" do
    subject(:pizza) { PizzasDomain::Pizza.new(name: "Margherita") }

    it "#to_model returns self" do
      expect(pizza.to_model).to equal(pizza)
    end

    it "#attributes returns a string-keyed hash" do
      attrs = pizza.attributes
      expect(attrs["name"]).to eq("Margherita")
      expect(attrs).to have_key("id")
      expect(attrs).to have_key("created_at")
    end

    it "#serializable_hash supports :only" do
      hash = pizza.serializable_hash(only: ["name"])
      expect(hash.keys).to eq(["name"])
    end

    it "#serializable_hash supports :except" do
      hash = pizza.serializable_hash(except: ["id"])
      expect(hash).not_to have_key("id")
      expect(hash["name"]).to eq("Margherita")
    end

    it "#as_json returns a JSON-compatible hash" do
      json = pizza.as_json
      expect(json["name"]).to eq("Margherita")
      expect(json).to have_key("id")
    end

    it "#to_partial_path includes the model name" do
      expect(pizza.to_partial_path).to include("pizza")
    end

    it "#read_attribute_for_serialization delegates to the accessor" do
      expect(pizza.read_attribute_for_serialization(:name)).to eq("Margherita")
    end
  end

  describe "AggregateCompat" do
    subject(:pizza) { PizzasDomain::Pizza.new(name: "Margherita") }

    it "#to_param returns the id" do
      expect(pizza.to_param).to eq(pizza.id)
    end

    it "#to_key returns [id] when persisted" do
      expect(pizza.to_key).to eq([pizza.id])
    end

    it "#persisted? is true when id is present" do
      expect(pizza).to be_persisted
    end

    it "#new_record? is false when persisted" do
      expect(pizza).not_to be_new_record
    end

    it "#destroyed? defaults to false" do
      expect(pizza).not_to be_destroyed
    end

    it "#errors returns an ActiveModel::Errors" do
      expect(pizza.errors).to be_a(ActiveModel::Errors)
      expect(pizza.errors).to be_empty
    end

    it "model_name strips the domain module prefix" do
      expect(PizzasDomain::Pizza.model_name.to_s).to eq("Pizza")
    end

    it "model_name provides singular and plural" do
      expect(PizzasDomain::Pizza.model_name.singular).to eq("pizza")
      expect(PizzasDomain::Pizza.model_name.plural).to eq("pizzas")
    end
  end

  describe "ValueObjectCompat" do
    subject(:topping) { PizzasDomain::Pizza::Topping.new(name: "Cheese", amount: 2) }

    it "#persisted? is false" do
      expect(topping).not_to be_persisted
    end

    it "#new_record? is true" do
      expect(topping).to be_new_record
    end

    it "#destroyed? is false" do
      expect(topping).not_to be_destroyed
    end

    it "#to_param is nil" do
      expect(topping.to_param).to be_nil
    end

    it "#to_key is nil" do
      expect(topping.to_key).to be_nil
    end

    it "#attributes returns a hash of attributes" do
      attrs = topping.attributes
      expect(attrs["name"]).to eq("Cheese")
      expect(attrs["amount"]).to eq(2)
    end

    it "#as_json returns a JSON-compatible hash" do
      json = topping.as_json
      expect(json["name"]).to eq("Cheese")
      expect(json["amount"]).to eq(2)
    end

    it "model_name strips the namespace" do
      expect(PizzasDomain::Pizza::Topping.model_name.to_s).to eq("Topping")
    end

    it "does not include validations (frozen objects)" do
      expect(topping).not_to respond_to(:valid?)
    end
  end

  describe "ValidationWiring" do
    it "wires DSL presence validation to ActiveModel" do
      blank = PizzasDomain::Pizza.new(name: "")
      expect(blank).not_to be_valid
      expect(blank.errors[:name]).to include("can't be blank")
    end

    it "passes validation for valid objects" do
      pizza = PizzasDomain::Pizza.new(name: "Margherita")
      expect(pizza).to be_valid
      expect(pizza.errors).to be_empty
    end

    it "returns false for nil values" do
      pizza = PizzasDomain::Pizza.new(name: nil)
      expect(pizza).not_to be_valid
    end

    it "clears errors on re-validation" do
      pizza = PizzasDomain::Pizza.new(name: "Margherita")
      pizza.valid?
      expect(pizza.errors).to be_empty
    end

    it "makes validates available as a class method" do
      expect(PizzasDomain::Pizza).to respond_to(:validates)
    end

    it "allows constructing invalid objects (no constructor raise)" do
      expect { PizzasDomain::Pizza.new(name: "") }.not_to raise_error
    end
  end

  describe "ValidationWiring via Introspection (domain_def)" do
    before(:all) do
      domain = Hecks.domain "Garage" do
        aggregate "Car" do
          attribute :make, String
          validation :make, presence: true
          command "CreateCar" do
            attribute :make, String
          end
        end
      end

      Hecks.load_domain(domain)
      @app = Hecks::Services::Application.new(domain)
      ActiveHecks.activate(GarageDomain)
    end

    it "wires validations from domain_def when domain: is not passed" do
      car = GarageDomain::Car.new(make: "")
      expect(car).not_to be_valid
      expect(car.errors[:make]).to include("can't be blank")
    end
  end

  describe "PersistenceWrapper" do
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
        BakeryDomain::Bread.new(name: "").save
        expect(BakeryDomain::Bread.count).to eq(count_before)
      end

      it "persists valid objects" do
        count_before = BakeryDomain::Bread.count
        BakeryDomain::Bread.new(name: "Rye").save
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

    describe "#destroy" do
      it "runs destroy callbacks" do
        called = false
        BakeryDomain::Bread.after_destroy { called = true }
        bread = BakeryDomain::Bread.new(name: "Focaccia")
        bread.save
        bread.destroy
        expect(called).to eq(true)
      end

      it "marks the object as destroyed" do
        bread = BakeryDomain::Bread.new(name: "Baguette")
        bread.save
        bread.destroy
        expect(bread).to be_destroyed
      end
    end

    describe "save callbacks" do
      it "runs before_save" do
        called = false
        BakeryDomain::Bread.before_save { called = true }
        BakeryDomain::Bread.new(name: "Ciabatta").save
        expect(called).to eq(true)
      end

      it "runs after_save" do
        called = false
        BakeryDomain::Bread.after_save { called = true }
        BakeryDomain::Bread.new(name: "Brioche").save
        expect(called).to eq(true)
      end

      it "does not run save callbacks when invalid" do
        called = false
        BakeryDomain::Bread.before_save { called = true }
        BakeryDomain::Bread.new(name: "").save
        expect(called).to eq(false)
      end
    end
  end
end

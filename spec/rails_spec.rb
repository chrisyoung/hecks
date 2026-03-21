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
    # Generate and load the domain once for all specs
    @tmpdir = Dir.mktmpdir("hecks_rails_test")
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

    gen = Hecks::Generators::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: @tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    entry = File.join(lib_path, "pizzas_domain.rb")
    load entry
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }

    ActiveHecks.activate(PizzasDomain)
  end

  after(:all) do
    FileUtils.rm_rf(@tmpdir) if @tmpdir
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

    describe "#to_partial_path" do
      it "returns a partial path" do
        expect(pizza.to_partial_path).to include("pizza")
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
  end
end

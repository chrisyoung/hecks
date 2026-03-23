require "spec_helper"
require "tmpdir"

RSpec.describe "Bounded Contexts" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      context "Ordering" do
        aggregate "Order" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer

          command "PlaceOrder" do
            attribute :pizza_id, reference_to("Pizza")
            attribute :quantity, Integer
          end
        end

        aggregate "Pizza" do
          attribute :name, String

          command "CreatePizza" do
            attribute :name, String
          end
        end
      end

      context "Kitchen" do
        aggregate "Recipe" do
          attribute :name, String
          attribute :prep_time, Integer

          command "CreateRecipe" do
            attribute :name, String
            attribute :prep_time, Integer
          end
        end
      end
    end
  end

  describe "DSL" do
    it "creates a domain with multiple contexts" do
      expect(domain.contexts.size).to eq(2)
    end

    it "has the correct context names" do
      expect(domain.contexts.map(&:name)).to eq(["Ordering", "Kitchen"])
    end

    it "has aggregates within each context" do
      ordering = domain.find_context("Ordering")
      expect(ordering.aggregates.map(&:name)).to eq(["Order", "Pizza"])

      kitchen = domain.find_context("Kitchen")
      expect(kitchen.aggregates.map(&:name)).to eq(["Recipe"])
    end

    it "aggregates flattens across all contexts" do
      expect(domain.aggregates.map(&:name)).to eq(["Order", "Pizza", "Recipe"])
    end

    it "is not single_context?" do
      expect(domain).not_to be_single_context
    end

    it "has_explicit_contexts?" do
      expect(domain.has_explicit_contexts?).to be true
    end
  end

  describe "backward compatibility" do
    let(:flat_domain) do
      Hecks.domain "Simple" do
        aggregate "Thing" do
          attribute :name, String
          command "CreateThing" do
            attribute :name, String
          end
        end
      end
    end

    it "wraps bare aggregates in a Default context" do
      expect(flat_domain.contexts.size).to eq(1)
      expect(flat_domain.contexts.first).to be_default
    end

    it "is single_context?" do
      expect(flat_domain).to be_single_context
    end

    it "does not have explicit contexts" do
      expect(flat_domain.has_explicit_contexts?).to be false
    end
  end

  describe "validation" do
    it "rejects cross-context references" do
      bad_domain = Hecks.domain "Bad" do
        context "Ordering" do
          aggregate "Order" do
            attribute :recipe_id, reference_to("Recipe")
            command "PlaceOrder" do
              attribute :recipe_id, reference_to("Recipe")
            end
          end
        end

        context "Kitchen" do
          aggregate "Recipe" do
            attribute :name, String
            command "CreateRecipe" do
              attribute :name, String
            end
          end
        end
      end

      validator = Hecks::Validator.new(bad_domain)
      expect(validator).not_to be_valid
      expect(validator.errors.first).to include("across context boundary")
    end

    it "allows within-context references" do
      expect(Hecks::Validator.new(domain)).to be_valid
    end

    it "allows cross-context event policies" do
      domain_with_policy = Hecks.domain "Pizzas" do
        context "Ordering" do
          aggregate "Order" do
            attribute :quantity, Integer
            command "PlaceOrder" do
              attribute :quantity, Integer
            end
          end
        end

        context "Kitchen" do
          aggregate "Recipe" do
            attribute :name, String
            command "PrepareRecipe" do
              attribute :name, String
            end

            policy "StartPrep" do
              on "PlacedOrder"
              trigger "PrepareRecipe"
            end
          end
        end
      end

      expect(Hecks::Validator.new(domain_with_policy)).to be_valid
    end
  end

  describe "code generation" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:generator) { Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "1.0.0", output_dir: tmpdir) }
    let(:gem_root) { File.join(tmpdir, "pizzas_domain") }

    after { FileUtils.rm_rf(tmpdir) }
    before { generator.generate }

    it "creates context directories" do
      expect(Dir.exist?(File.join(gem_root, "lib/pizzas_domain/ordering"))).to be true
      expect(Dir.exist?(File.join(gem_root, "lib/pizzas_domain/kitchen"))).to be true
    end

    it "creates aggregate files under context dirs" do
      expect(File.exist?(File.join(gem_root, "lib/pizzas_domain/ordering/order/order.rb"))).to be true
      expect(File.exist?(File.join(gem_root, "lib/pizzas_domain/ordering/pizza/pizza.rb"))).to be true
      expect(File.exist?(File.join(gem_root, "lib/pizzas_domain/kitchen/recipe/recipe.rb"))).to be true
    end

    it "creates context-namespaced ports" do
      expect(File.exist?(File.join(gem_root, "lib/pizzas_domain/ports/ordering/order_repository.rb"))).to be true
      expect(File.exist?(File.join(gem_root, "lib/pizzas_domain/ports/kitchen/recipe_repository.rb"))).to be true
    end

    it "creates context-namespaced adapters" do
      expect(File.exist?(File.join(gem_root, "lib/pizzas_domain/adapters/ordering/order_memory_repository.rb"))).to be true
    end

    it "generates entry point with context modules" do
      content = File.read(File.join(gem_root, "lib/pizzas_domain.rb"))
      expect(content).to include("module Ordering")
      expect(content).to include("module Kitchen")
    end

    it "generates context-namespaced aggregate code" do
      content = File.read(File.join(gem_root, "lib/pizzas_domain/ordering/order/order.rb"))
      expect(content).to include("module PizzasDomain")
      expect(content).to include("module Ordering")
      expect(content).to include("class Order")
    end

    it "generates context-namespaced specs" do
      expect(File.exist?(File.join(gem_root, "spec/ordering/order/order_spec.rb"))).to be true
      content = File.read(File.join(gem_root, "spec/ordering/order/order_spec.rb"))
      expect(content).to include("PizzasDomain::Ordering::Order")
    end

    it "generates loadable code" do
      lib_path = File.join(gem_root, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

      entry = File.join(lib_path, "pizzas_domain.rb")
      load entry
      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }

      expect(defined?(PizzasDomain::Ordering::Order)).to be_truthy
      expect(defined?(PizzasDomain::Ordering::Pizza)).to be_truthy
      expect(defined?(PizzasDomain::Kitchen::Recipe)).to be_truthy
    end
  end

  describe "services with multiple contexts" do
    let(:tmpdir) { Dir.mktmpdir }

    before do
      gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
      gem_path = gen.generate
      lib_path = File.join(gem_path, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      load File.join(lib_path, "pizzas_domain.rb")
      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    end

    after { FileUtils.rm_rf(tmpdir) }

    let!(:app) { Hecks::Services::Application.new(domain) }

    it "provides context-qualified repository access" do
      expect(app["Ordering"]["Order"]).to be_a(PizzasDomain::Adapters::Ordering::OrderMemoryRepository)
      expect(app["Kitchen"]["Recipe"]).to be_a(PizzasDomain::Adapters::Kitchen::RecipeMemoryRepository)
    end

    it "hoists context modules to top level" do
      expect(::Ordering::Order).to eq(PizzasDomain::Ordering::Order)
      expect(::Kitchen::Recipe).to eq(PizzasDomain::Kitchen::Recipe)
    end

    it "defines command methods on aggregate classes" do
      expect(PizzasDomain::Ordering::Order).to respond_to(:place)
      expect(PizzasDomain::Kitchen::Recipe).to respond_to(:create)
    end

    it "dispatches commands and fires events" do
      received = nil
      app.on("PlacedOrder") { |e| received = e }

      PizzasDomain::Ordering::Order.place(pizza_id: "abc", quantity: 3)

      expect(received).not_to be_nil
      expect(received.quantity).to eq(3)
    end

    it "saves to the correct repository" do
      PizzasDomain::Ordering::Pizza.create(name: "Margherita")
      expect(app["Ordering"]["Pizza"].count).to eq(1)
    end

    it "allows cross-context events via shared bus" do
      kitchen_received = nil
      app.on("PlacedOrder") { |e| kitchen_received = e }

      PizzasDomain::Ordering::Order.place(pizza_id: "xyz", quantity: 5)
      expect(kitchen_received.quantity).to eq(5)
    end
  end
end

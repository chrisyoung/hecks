require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Generators::Infrastructure::DomainGemGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
          attribute :description, String
        end

        command "AddTopping" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :topping, String
        end
      end

      aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer

        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end

        policy "ReserveIngredients" do
          on "PlacedOrder"
          trigger "ReserveStock"
        end
      end
    end
  end

  let(:tmpdir) { Dir.mktmpdir }
  let(:generator) { described_class.new(domain, version: "1.0.0", output_dir: tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  before { generator.generate }

  let(:gem_root) { File.join(tmpdir, "pizzas_domain") }

  it "creates the gem directory" do
    expect(Dir.exist?(gem_root)).to be true
  end

  it "creates the gemspec" do
    expect(File.exist?(File.join(gem_root, "pizzas_domain.gemspec"))).to be true
  end

  it "creates the entry point" do
    path = File.join(gem_root, "lib/pizzas_domain.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("module PizzasDomain")
    expect(content).to include("autoload :Pizza")
    expect(content).to include("autoload :Order")
  end

  it "creates the aggregate root" do
    path = File.join(gem_root, "lib/pizzas_domain/pizza/pizza.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("class Pizza")
    expect(content).to include("include Hecks::Model")
    expect(content).to include("attr_reader :name, :description, :toppings")
  end

  it "creates value objects" do
    path = File.join(gem_root, "lib/pizzas_domain/pizza/topping.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("class Topping")
    expect(content).to include("freeze")
  end

  it "creates commands" do
    path = File.join(gem_root, "lib/pizzas_domain/pizza/commands/create_pizza.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("class CreatePizza")
  end

  it "creates events" do
    path = File.join(gem_root, "lib/pizzas_domain/pizza/events/created_pizza.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("class CreatedPizza")
    expect(content).to include("occurred_at")
  end

  it "creates policies" do
    path = File.join(gem_root, "lib/pizzas_domain/order/policies/reserve_ingredients.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("class ReserveIngredients")
    expect(content).to include("PlacedOrder")
  end

  it "creates ports" do
    path = File.join(gem_root, "lib/pizzas_domain/ports/pizza_repository.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("module PizzaRepository")
    expect(content).to include("NotImplementedError")
  end

  it "creates memory adapters" do
    path = File.join(gem_root, "lib/pizzas_domain/adapters/pizza_memory_repository.rb")
    expect(File.exist?(path)).to be true
    content = File.read(path)
    expect(content).to include("class PizzaMemoryRepository")
    expect(content).to include("include Ports::PizzaRepository")
    expect(content).to include("@store")
  end

  it "autoloads adapters in entry point" do
    content = File.read(File.join(gem_root, "lib/pizzas_domain.rb"))
    expect(content).to include("module Adapters")
    expect(content).to include("autoload :PizzaMemoryRepository")
    expect(content).to include("autoload :OrderMemoryRepository")
  end

  it "creates specs" do
    expect(File.exist?(File.join(gem_root, "spec/spec_helper.rb"))).to be true
    expect(File.exist?(File.join(gem_root, "spec/pizza/pizza_spec.rb"))).to be true
    expect(File.exist?(File.join(gem_root, "spec/pizza/topping_spec.rb"))).to be true
    expect(File.exist?(File.join(gem_root, "spec/pizza/commands/create_pizza_spec.rb"))).to be true
    expect(File.exist?(File.join(gem_root, "spec/pizza/events/created_pizza_spec.rb"))).to be true
  end

  it "sets the version in the gemspec" do
    content = File.read(File.join(gem_root, "pizzas_domain.gemspec"))
    expect(content).to include('"1.0.0"')
  end
end

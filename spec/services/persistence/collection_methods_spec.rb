require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Persistence::CollectionMethods do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  before do
    tmpdir = Dir.mktmpdir("hecks_collection_methods_test")
    gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "pizzas_domain.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    @app = Hecks::Services::Application.new(domain)
  end

  it "defines accessor for list attributes" do
    pizza = PizzasDomain::Pizza.create(name: "Margherita")
    expect(pizza).to respond_to(:toppings)
  end

  it "returns a CollectionProxy" do
    pizza = PizzasDomain::Pizza.create(name: "Margherita")
    expect(pizza.toppings).to be_a(Hecks::Services::Persistence::CollectionProxy)
  end
end

require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Persistence::ReferenceMethods do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String

        command "CreatePizza" do
          attribute :name, String
        end
      end

      aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer

        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end
      end
    end
  end

  before do
    tmpdir = Dir.mktmpdir("hecks_reference_methods_test")
    gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "pizzas_domain.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    @app = Hecks::Services::Application.new(domain)
  end

  it "resolves references" do
    pizza = PizzasDomain::Pizza.create(name: "Margherita")
    order = PizzasDomain::Order.place(pizza_id: pizza.id, quantity: 3)
    expect(order.pizza.name).to eq("Margherita")
  end

  it "returns nil for nil ref_id" do
    order = PizzasDomain::Order.place(pizza_id: nil, quantity: 1)
    expect(order.pizza).to be_nil
  end
end

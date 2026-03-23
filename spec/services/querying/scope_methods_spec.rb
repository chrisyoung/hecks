require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Querying::ScopeMethods do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end

        scope :classics, style: "Classic"
        scope :by_style, ->(s) { { style: s } }
      end
    end
  end

  before do
    tmpdir = Dir.mktmpdir("hecks_scope_methods_test")
    gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "pizzas_domain.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    @app = Hecks::Services::Application.new(domain)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")
  end

  it "defines hash scope as class method" do
    results = PizzasDomain::Pizza.classics
    expect(results.map(&:name)).to eq(["Margherita"])
  end

  it "defines lambda scope with arguments" do
    results = PizzasDomain::Pizza.by_style("Spicy")
    expect(results.map(&:name)).to eq(["Pepperoni"])
  end
end

require "spec_helper"
require "stringio"
require "tmpdir"
require "json"

RSpec.describe Hecks::HTTP::RouteBuilder do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end

        query "Classics" do
          where(style: "Classic")
        end

        query "ByStyle" do |style|
          where(style: style)
        end
      end
    end
  end

  before do
    tmpdir = Dir.mktmpdir("hecks_route_test")
    gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "pizzas_domain.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    @app = Hecks::Services::Application.new(domain)
    @mod = PizzasDomain
    @routes = described_class.new(domain, @mod).build
  end

  it "generates CRUD routes for each aggregate" do
    paths = @routes.map { |r| "#{r[:method]} #{r[:path]}" }
    expect(paths).to include("GET /pizzas")
    expect(paths).to include("GET /pizzas/:id")
    expect(paths).to include("POST /pizzas")
    expect(paths).to include("DELETE /pizzas/:id")
  end

  it "generates query routes" do
    paths = @routes.map { |r| r[:path] }
    expect(paths).to include("/pizzas/classics")
    expect(paths).to include("/pizzas/by_style")
  end

  it "query routes come before :id routes" do
    classics_idx = @routes.index { |r| r[:path] == "/pizzas/classics" }
    id_idx = @routes.index { |r| r[:path] == "/pizzas/:id" }
    expect(classics_idx).to be < id_idx
  end

  it "serializes CollectionProxy as array, not object string" do
    PizzasDomain::Pizza.create(name: "Test", style: "Classic")
    pizza = PizzasDomain::Pizza.first
    route = @routes.find { |r| r[:method] == "GET" && r[:path] == "/pizzas/:id" }
    req = double(path: "/pizzas/#{pizza.id}", params: {}, body: StringIO.new(""))
    result = route[:handler].call(req)
    expect(result["toppings"]).to be_an(Array)
  end

  it "serializes Time as ISO8601" do
    PizzasDomain::Pizza.create(name: "Test", style: "Classic")
    route = @routes.find { |r| r[:method] == "GET" && r[:path] == "/pizzas" }
    req = double(path: "/pizzas", params: {}, body: StringIO.new(""))
    result = route[:handler].call(req)
    expect(result.first["created_at"]).to match(/^\d{4}-\d{2}-\d{2}T/)
  end
end

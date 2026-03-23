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

  def fake_request(path:, params: {}, body: "")
    double(path: path, params: params, body: StringIO.new(body))
  end

  describe "route generation" do
    it "generates GET, POST, DELETE for each aggregate" do
      paths = @routes.map { |r| "#{r[:method]} #{r[:path]}" }
      expect(paths).to include("GET /pizzas", "GET /pizzas/:id", "POST /pizzas", "DELETE /pizzas/:id")
    end

    it "generates query routes" do
      paths = @routes.map { |r| r[:path] }
      expect(paths).to include("/pizzas/classics", "/pizzas/by_style")
    end
  end

  describe "route priority" do
    it "places query routes before :id catch-all" do
      classics_idx = @routes.index { |r| r[:path] == "/pizzas/classics" }
      id_idx = @routes.index { |r| r[:path] == "/pizzas/:id" }
      expect(classics_idx).to be < id_idx
    end
  end

  describe "POST handler" do
    it "creates an aggregate from JSON body and returns serialized result" do
      route = @routes.find { |r| r[:method] == "POST" && r[:path] == "/pizzas" }
      req = fake_request(path: "/pizzas", body: '{"name":"Margherita","style":"Classic"}')
      result = route[:handler].call(req)
      expect(result["name"]).to eq("Margherita")
      expect(result["style"]).to eq("Classic")
      expect(result["id"]).not_to be_nil
    end
  end

  describe "GET all handler" do
    it "returns array of all aggregates" do
      PizzasDomain::Pizza.create(name: "A", style: "Classic")
      PizzasDomain::Pizza.create(name: "B", style: "Spicy")
      route = @routes.find { |r| r[:method] == "GET" && r[:path] == "/pizzas" }
      result = route[:handler].call(fake_request(path: "/pizzas"))
      expect(result.size).to eq(2)
      expect(result.map { |r| r["name"] }).to contain_exactly("A", "B")
    end
  end

  describe "GET by ID handler" do
    it "returns the aggregate" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      route = @routes.find { |r| r[:method] == "GET" && r[:path] == "/pizzas/:id" }
      result = route[:handler].call(fake_request(path: "/pizzas/#{pizza.id}"))
      expect(result["name"]).to eq("Margherita")
    end

    it "raises when not found" do
      route = @routes.find { |r| r[:method] == "GET" && r[:path] == "/pizzas/:id" }
      expect { route[:handler].call(fake_request(path: "/pizzas/nonexistent")) }.to raise_error("Not found")
    end
  end

  describe "DELETE handler" do
    it "deletes and returns confirmation" do
      pizza = PizzasDomain::Pizza.create(name: "Temp", style: "Classic")
      route = @routes.find { |r| r[:method] == "DELETE" && r[:path] == "/pizzas/:id" }
      result = route[:handler].call(fake_request(path: "/pizzas/#{pizza.id}"))
      expect(result[:deleted]).to eq(pizza.id)
      expect(PizzasDomain::Pizza.find(pizza.id)).to be_nil
    end
  end

  describe "query handlers" do
    before do
      PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")
    end

    it "handles parameterless query" do
      route = @routes.find { |r| r[:path] == "/pizzas/classics" }
      result = route[:handler].call(fake_request(path: "/pizzas/classics"))
      expect(result.size).to eq(1)
      expect(result.first["name"]).to eq("Margherita")
    end

    it "handles parameterized query" do
      route = @routes.find { |r| r[:path] == "/pizzas/by_style" }
      result = route[:handler].call(fake_request(path: "/pizzas/by_style", params: { "style" => "Spicy" }))
      expect(result.size).to eq(1)
      expect(result.first["name"]).to eq("Pepperoni")
    end
  end

  describe "serialization" do
    it "serializes CollectionProxy as empty array" do
      PizzasDomain::Pizza.create(name: "Test", style: "Classic")
      route = @routes.find { |r| r[:method] == "GET" && r[:path] == "/pizzas" }
      result = route[:handler].call(fake_request(path: "/pizzas"))
      expect(result.first["toppings"]).to eq([])
    end

    it "serializes Time as ISO8601 string" do
      PizzasDomain::Pizza.create(name: "Test", style: "Classic")
      route = @routes.find { |r| r[:method] == "GET" && r[:path] == "/pizzas" }
      result = route[:handler].call(fake_request(path: "/pizzas"))
      expect(result.first["created_at"]).to match(/^\d{4}-\d{2}-\d{2}T/)
    end
  end
end

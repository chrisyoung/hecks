require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Querying::Operators do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :price, Float

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
          attribute :price, Float
        end
      end
    end
  end

  before do
    tmpdir = Dir.mktmpdir("hecks_operators_test")
    gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "pizzas_domain.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    @app = Hecks::Services::Application.new(domain)

    repo = @app["Pizza"]
    Hecks::Services::Querying::AdHocQueries.bind(PizzasDomain::Pizza, repo)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic", price: 12.0)
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy", price: 15.0)
    PizzasDomain::Pizza.create(name: "Hawaiian", style: "Tropical", price: 14.0)
    PizzasDomain::Pizza.create(name: "Cheese", style: "Classic", price: 10.0)
  end

  describe "gt" do
    it "filters greater than" do
      results = PizzasDomain::Pizza.where(price: Hecks::Services::Querying::Operators::Gt.new(13.0))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end
  end

  describe "gte" do
    it "filters greater than or equal" do
      results = PizzasDomain::Pizza.where(price: Hecks::Services::Querying::Operators::Gte.new(14.0))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end
  end

  describe "lt" do
    it "filters less than" do
      results = PizzasDomain::Pizza.where(price: Hecks::Services::Querying::Operators::Lt.new(13.0))
      expect(results.map(&:name)).to contain_exactly("Margherita", "Cheese")
    end
  end

  describe "lte" do
    it "filters less than or equal" do
      results = PizzasDomain::Pizza.where(price: Hecks::Services::Querying::Operators::Lte.new(12.0))
      expect(results.map(&:name)).to contain_exactly("Margherita", "Cheese")
    end
  end

  describe "not_eq" do
    it "filters not equal" do
      results = PizzasDomain::Pizza.where(style: Hecks::Services::Querying::Operators::NotEq.new("Classic"))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end
  end

  describe "one_of (in)" do
    it "filters by inclusion in a set" do
      results = PizzasDomain::Pizza.where(style: Hecks::Services::Querying::Operators::In.new(["Classic", "Tropical"]))
      expect(results.map(&:name)).to contain_exactly("Margherita", "Hawaiian", "Cheese")
    end
  end

  describe "operators via QueryBuilder helpers" do
    it "gt helper works in DSL queries" do
      builder = Hecks::Services::Querying::QueryBuilder.new(@app["Pizza"])
      results = builder.where(price: builder.gt(13.0))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end

    it "not_eq helper works" do
      builder = Hecks::Services::Querying::QueryBuilder.new(@app["Pizza"])
      results = builder.where(style: builder.not_eq("Classic"))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end

    it "one_of helper works" do
      builder = Hecks::Services::Querying::QueryBuilder.new(@app["Pizza"])
      results = builder.where(style: builder.one_of(["Spicy", "Tropical"]))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end

    it "operators chain with other conditions" do
      builder = Hecks::Services::Querying::QueryBuilder.new(@app["Pizza"])
      results = builder.where(style: builder.not_eq("Classic")).where(price: builder.lt(15.0))
      expect(results.map(&:name)).to eq(["Hawaiian"])
    end
  end
end

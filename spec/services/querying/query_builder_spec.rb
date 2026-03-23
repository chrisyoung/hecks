require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Querying::QueryBuilder do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end

        query "Classics" do
          where(style: "Classic").order(:name)
        end

        query "ByStyle" do |style|
          where(style: style)
        end
      end
    end
  end

  before do
    tmpdir = Dir.mktmpdir("hecks_query_test")
    gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    entry = File.join(lib_path, "pizzas_domain.rb")
    load entry
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    @app = Hecks::Services::Application.new(domain)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Classic")
    PizzasDomain::Pizza.create(name: "Hawaiian", style: "Tropical")
    PizzasDomain::Pizza.create(name: "BBQ Chicken", style: "American")
  end

  describe "DSL query objects" do
    it "wires query classes as class methods" do
      expect(PizzasDomain::Pizza).to respond_to(:classics)
      expect(PizzasDomain::Pizza).to respond_to(:by_style)
    end

    it "classics returns Classic pizzas ordered by name" do
      results = PizzasDomain::Pizza.classics
      expect(results.map(&:name)).to eq(["Margherita", "Pepperoni"])
    end

    it "by_style accepts an argument" do
      results = PizzasDomain::Pizza.by_style("Tropical")
      expect(results.map(&:name)).to eq(["Hawaiian"])
    end

    it "query results are chainable" do
      results = PizzasDomain::Pizza.classics.limit(1)
      expect(results.map(&:name)).to eq(["Margherita"])
    end
  end

  describe "adapter delegation" do
    it "delegates to the adapter's query method" do
      repo = @app["Pizza"]
      expect(repo).to respond_to(:query)
      results = repo.query(conditions: { style: "Classic" }, order_key: :name, order_direction: :asc, limit: nil, offset: nil)
      expect(results.map(&:name)).to eq(["Margherita", "Pepperoni"])
    end
  end

  context "with ad-hoc queries enabled" do
    before do
      repo = @app["Pizza"]
      Hecks::Services::Querying::AdHocQueries.bind(PizzasDomain::Pizza, repo)
    end

    describe ".where" do
      it "filters by a single attribute" do
        results = PizzasDomain::Pizza.where(style: "Classic")
        expect(results.map(&:name)).to contain_exactly("Margherita", "Pepperoni")
      end

      it "filters by multiple attributes" do
        results = PizzasDomain::Pizza.where(style: "Classic", name: "Pepperoni")
        expect(results.map(&:name)).to eq(["Pepperoni"])
      end

      it "returns empty when nothing matches" do
        results = PizzasDomain::Pizza.where(style: "NonExistent")
        expect(results.to_a).to be_empty
      end

      it "is chainable" do
        results = PizzasDomain::Pizza.where(style: "Classic").where(name: "Margherita")
        expect(results.map(&:name)).to eq(["Margherita"])
      end
    end

    describe ".find_by" do
      it "returns the first matching object" do
        result = PizzasDomain::Pizza.find_by(name: "Hawaiian")
        expect(result.name).to eq("Hawaiian")
      end

      it "returns nil when nothing matches" do
        result = PizzasDomain::Pizza.find_by(name: "NonExistent")
        expect(result).to be_nil
      end
    end

    describe "#order" do
      it "sorts ascending by default" do
        results = PizzasDomain::Pizza.where(style: "Classic").order(:name)
        expect(results.map(&:name)).to eq(["Margherita", "Pepperoni"])
      end

      it "sorts descending with hash syntax" do
        results = PizzasDomain::Pizza.where(style: "Classic").order(name: :desc)
        expect(results.map(&:name)).to eq(["Pepperoni", "Margherita"])
      end
    end

    describe "#limit and #offset" do
      it "limits results" do
        results = PizzasDomain::Pizza.where(style: "Classic").limit(1)
        expect(results.to_a.size).to eq(1)
      end

      it "offsets results" do
        results = PizzasDomain::Pizza.where(style: "Classic").order(:name).offset(1)
        expect(results.map(&:name)).to eq(["Pepperoni"])
      end

      it "paginates" do
        page = PizzasDomain::Pizza.where(**{}).order(:name).offset(1).limit(2)
        expect(page.map(&:name)).to eq(["Hawaiian", "Margherita"])
      end
    end

    describe "#count, #first, #last" do
      it "counts matching results" do
        expect(PizzasDomain::Pizza.where(style: "Classic").count).to eq(2)
      end

      it "returns first" do
        result = PizzasDomain::Pizza.where(style: "Classic").order(:name).first
        expect(result.name).to eq("Margherita")
      end

      it "returns last" do
        result = PizzasDomain::Pizza.where(style: "Classic").order(:name).last
        expect(result.name).to eq("Pepperoni")
      end
    end

    describe "Enumerable" do
      it "supports each" do
        names = []
        PizzasDomain::Pizza.where(style: "Classic").each { |p| names << p.name }
        expect(names).to contain_exactly("Margherita", "Pepperoni")
      end

      it "supports map" do
        names = PizzasDomain::Pizza.where(style: "Classic").map(&:name)
        expect(names).to contain_exactly("Margherita", "Pepperoni")
      end

      it "supports empty?" do
        expect(PizzasDomain::Pizza.where(style: "NonExistent")).to be_empty
      end
    end
  end
end

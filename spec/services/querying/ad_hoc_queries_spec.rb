require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Querying::AdHocQueries do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end
      end
    end
  end

  before do
    tmpdir = Dir.mktmpdir("hecks_ad_hoc_test")
    gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "pizzas_domain.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    @app = Hecks::Services::Application.new(domain)

    repo = @app["Pizza"]
    described_class.bind(PizzasDomain::Pizza, repo)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")
  end

  describe ".bind" do
    it "extends the class with query methods" do
      expect(PizzasDomain::Pizza.singleton_class.ancestors).to include(described_class)
    end
  end

  describe ".where" do
    it "filters by conditions" do
      results = PizzasDomain::Pizza.where(style: "Classic")
      expect(results.map(&:name)).to eq(["Margherita"])
    end
  end

  describe ".find_by" do
    it "returns first match" do
      result = PizzasDomain::Pizza.find_by(name: "Pepperoni")
      expect(result.name).to eq("Pepperoni")
    end

    it "returns nil when no match" do
      expect(PizzasDomain::Pizza.find_by(name: "Nonexistent")).to be_nil
    end
  end
end

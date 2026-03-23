require "spec_helper"
require "tmpdir"

RSpec.describe "Scopes" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :status, String

        scope :active, status: "active"
        scope :by_name, ->(name) { { name: name } }

        command "CreatePizza" do
          attribute :name, String
          attribute :status, String
        end
      end
    end
  end

  describe "DSL definition" do
    it "stores scopes on the aggregate" do
      agg = domain.aggregates.first
      expect(agg.scopes.size).to eq(2)
      expect(agg.scopes.map(&:name)).to eq([:active, :by_name])
    end

    it "distinguishes hash scopes from callable scopes" do
      agg = domain.aggregates.first
      active_scope = agg.scopes.find { |s| s.name == :active }
      by_name_scope = agg.scopes.find { |s| s.name == :by_name }
      expect(active_scope.callable?).to be false
      expect(by_name_scope.callable?).to be true
    end
  end

  describe "application wiring" do
    before do
      tmpdir = Dir.mktmpdir("hecks_scopes_test")
      gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
      gem_path = gen.generate
      lib_path = File.join(gem_path, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      entry = File.join(lib_path, "pizzas_domain.rb")
      load entry
      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
      @app = Hecks::Services::Application.new(domain)
    end

    it "defines hash scope as a class method" do
      expect(PizzasDomain::Pizza).to respond_to(:active)
    end

    it "defines lambda scope as a class method" do
      expect(PizzasDomain::Pizza).to respond_to(:by_name)
    end

    it "filters with hash scope" do
      PizzasDomain::Pizza.create(name: "Margherita", status: "active")
      PizzasDomain::Pizza.create(name: "Hawaiian", status: "inactive")

      results = PizzasDomain::Pizza.active
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Margherita")
    end

    it "filters with lambda scope" do
      PizzasDomain::Pizza.create(name: "Margherita", status: "active")
      PizzasDomain::Pizza.create(name: "Hawaiian", status: "active")

      results = PizzasDomain::Pizza.by_name("Hawaiian")
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Hawaiian")
    end
  end

  describe "DSL serialization" do
    it "includes hash scopes in serialized output" do
      output = Hecks::DslSerializer.new(domain).serialize
      expect(output).to include('scope :active, status: "active"')
    end

    it "omits lambda scopes from serialized output" do
      output = Hecks::DslSerializer.new(domain).serialize
      expect(output).not_to include("by_name")
    end
  end

  describe "aggregate rebuilder" do
    it "preserves hash scopes through rebuild" do
      agg = domain.aggregates.first
      builder = Hecks::DSL::AggregateRebuilder.from_aggregate(agg)
      rebuilt = builder.build
      hash_scopes = rebuilt.scopes.reject(&:callable?)
      expect(hash_scopes.size).to eq(1)
      expect(hash_scopes.first.name).to eq(:active)
      expect(hash_scopes.first.conditions).to eq(status: "active")
    end

    it "preserves lambda scopes through rebuild" do
      agg = domain.aggregates.first
      builder = Hecks::DSL::AggregateRebuilder.from_aggregate(agg)
      rebuilt = builder.build
      lambda_scopes = rebuilt.scopes.select(&:callable?)
      expect(lambda_scopes.size).to eq(1)
      expect(lambda_scopes.first.name).to eq(:by_name)
    end
  end
end

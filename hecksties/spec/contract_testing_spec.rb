require "spec_helper"
require "hecks/contract_testing"
require "tmpdir"

RSpec.describe Hecks::ContractTesting do
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

  before { @app = Hecks.load(domain) }

  describe "shared examples" do
    include_examples "hecks repository contract",
      adapter: -> { PizzasDomain::Adapters::PizzaMemoryRepository.new },
      factory: -> { PizzasDomain::Pizza.new(name: "Margherita", style: "Classic") }
  end

  describe ".generate_specs" do
    it "writes a contract spec file per aggregate" do
      Dir.mktmpdir do |dir|
        paths = Hecks::ContractTesting.generate_specs(domain, output_dir: dir)
        expect(paths.size).to eq(1)
        expect(File.basename(paths.first)).to eq("pizza_repository_contract_spec.rb")
        content = File.read(paths.first)
        expect(content).to include("hecks repository contract")
        expect(content).to include("PizzasDomain::Adapters::PizzaMemoryRepository")
        expect(content).to include("PizzasDomain::Pizza.new")
      end
    end
  end
end

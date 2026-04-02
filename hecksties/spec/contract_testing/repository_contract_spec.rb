require "spec_helper"
require "hecks/contract_testing"

RSpec.describe Hecks::ContractTesting::RepositoryContract do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  before { @app = Hecks.load(domain) }

  describe ".register!" do
    it "registers the shared example group" do
      groups = RSpec.world.shared_example_group_registry
        .send(:shared_example_groups)[:main]
      expect(groups).to have_key("hecks repository contract")
    end
  end

  include_examples "hecks repository contract",
    adapter: -> { PizzasDomain::Adapters::PizzaMemoryRepository.new },
    factory: -> { PizzasDomain::Pizza.new(name: "Test") }
end

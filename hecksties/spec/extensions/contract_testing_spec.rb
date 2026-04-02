require "spec_helper"
require "hecks/contract_testing"

Hecks::ContractTesting.install!

RSpec.describe "Contract testing shared examples" do
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

  context "memory adapter" do
    it_behaves_like "a Hecks repository",
      domain: (Hecks.domain("Pizzas") do
        aggregate "Pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end),
      aggregate_name: "Pizza",
      create_attrs: { name: "Margherita" }
  end
end

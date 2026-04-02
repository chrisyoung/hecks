require "spec_helper"

RSpec.describe Hecks::DomainVersioning::ApiContract do
  let(:domain_v1) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  let(:domain_v2) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :size, String
        command "CreatePizza" do
          attribute :name, String
        end
        command "ResizePizza" do
          attribute :size, String
        end
      end
    end
  end

  describe ".serialize" do
    it "captures domain name and aggregates" do
      contract = described_class.serialize(domain_v1)
      expect(contract[:domain]).to eq("Pizzas")
      expect(contract[:aggregates].size).to eq(1)
      expect(contract[:aggregates].first[:name]).to eq("Pizza")
    end

    it "captures attributes and commands" do
      contract = described_class.serialize(domain_v1)
      agg = contract[:aggregates].first
      expect(agg[:attributes].map { |a| a[:name] }).to include("name")
      expect(agg[:commands].map { |c| c[:name] }).to include("CreatePizza")
    end
  end

  describe ".diff" do
    it "detects added attributes and commands" do
      old_contract = described_class.serialize(domain_v1)
      new_contract = described_class.serialize(domain_v2)
      diffs = described_class.diff(old_contract, new_contract)

      types = diffs.map { |d| d[:type] }
      expect(types).to include(:added_attribute)
      expect(types).to include(:added_command)
    end

    it "detects removed attributes" do
      old_contract = described_class.serialize(domain_v2)
      new_contract = described_class.serialize(domain_v1)
      diffs = described_class.diff(old_contract, new_contract)

      removed_attrs = diffs.select { |d| d[:type] == :removed_attribute }
      expect(removed_attrs).not_to be_empty
    end

    it "returns empty when contracts match" do
      contract = described_class.serialize(domain_v1)
      expect(described_class.diff(contract, contract)).to be_empty
    end
  end
end

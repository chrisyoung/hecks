require "spec_helper"

RSpec.describe Hecks::Utils do
  describe ".underscore" do
    it "converts CamelCase to snake_case" do
      expect(described_class.underscore("PizzaOrder")).to eq("pizza_order")
    end

    it "handles single words" do
      expect(described_class.underscore("Pizza")).to eq("pizza")
    end

    it "handles consecutive capitals" do
      expect(described_class.underscore("HTMLParser")).to eq("html_parser")
    end
  end

  describe ".type_label" do
    it "returns type name for scalar" do
      attr = Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)
      expect(described_class.type_label(attr)).to eq("String")
    end

    it "returns list_of for list types" do
      attr = Hecks::DomainModel::Structure::Attribute.new(name: :items, type: "Item", list: true)
      expect(described_class.type_label(attr)).to eq("list_of(Item)")
    end

    it "returns reference_to for references" do
      attr = Hecks::DomainModel::Structure::Attribute.new(name: :order_id, type: "Order", reference: true)
      expect(described_class.type_label(attr)).to eq("reference_to(Order)")
    end
  end

  describe ".block_source" do
    it "returns 'true' for nil block" do
      expect(described_class.block_source(nil)).to eq("true")
    end
  end
end

require "spec_helper"

RSpec.describe Hecks::DomainModel::Structure::Attribute do
  describe "a simple attribute" do
    subject(:attr) { described_class.new(name: :name, type: String) }

    it "has a name" do
      expect(attr.name).to eq(:name)
    end

    it "has a type" do
      expect(attr.type).to eq(String)
    end

    it "is not a list" do
      expect(attr).not_to be_list
    end

    it "is not a reference" do
      expect(attr).not_to be_reference
    end
  end

  describe "a list attribute" do
    subject(:attr) { described_class.new(name: :toppings, type: "Topping", list: true) }

    it "is a list" do
      expect(attr).to be_list
    end
  end

  describe "a reference attribute" do
    subject(:attr) { described_class.new(name: :pizza_id, type: "Pizza", reference: true) }

    it "is a reference" do
      expect(attr).to be_reference
    end

    it "has String as ruby_type" do
      expect(attr.ruby_type).to eq("String")
    end
  end
end

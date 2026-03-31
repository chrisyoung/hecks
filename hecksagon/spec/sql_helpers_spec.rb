require "spec_helper"

RSpec.describe Hecks::Migrations::Strategies::SqlHelpers do
  let(:helper) do
    Class.new { include Hecks::Migrations::Strategies::SqlHelpers }.new
  end

  describe "#table_name" do
    it "pluralizes and underscores" do
      expect(helper.table_name("Pizza")).to eq("pizzas")
    end

    it "handles multi-word names" do
      expect(helper.table_name("GovernancePolicy")).to eq("governance_policys")
    end
  end

  describe "#join_table_name" do
    it "combines aggregate and value object names" do
      expect(helper.join_table_name("Pizza", "Topping")).to eq("pizzas_toppings")
    end
  end

  describe "#index_name" do
    it "builds idx_ prefixed name" do
      expect(helper.index_name("Pizza", [:name, :size])).to eq("idx_pizzas_name_size")
    end
  end
end

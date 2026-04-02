require "spec_helper"

RSpec.describe Hecks::ValidationRules::Naming::AttributeNaming do
  def build_domain(attr_name, agg_name: "Pizza")
    Hecks.domain("Pizzas") do
      aggregate(agg_name) do
        attribute attr_name, String
        command("Create#{agg_name}") { attribute :name, String }
      end
    end
  end

  def warnings_for(domain)
    v = Hecks::Validator.new(domain)
    v.valid?
    v.warnings
  end

  describe "vague suffixes" do
    %w[order_data toppings_info customer_details].each do |name|
      it "warns about '#{name}'" do
        ws = warnings_for(build_domain(name.to_sym))
        expect(ws.any? { |w| w.include?(name) && w.include?("vague suffix") }).to be true
      end
    end
  end

  describe "redundant aggregate prefix" do
    it "warns about 'pizza_name' on Pizza" do
      ws = warnings_for(build_domain(:pizza_name))
      expect(ws.any? { |w| w.include?("pizza_name") && w.include?("redundant prefix") }).to be true
    end
  end

  describe "Hungarian-style type prefix" do
    it "warns about 'str_name'" do
      ws = warnings_for(build_domain(:str_name))
      expect(ws.any? { |w| w.include?("str_name") && w.include?("Hungarian") }).to be true
    end
  end

  describe "clean attribute names" do
    %w[name status description].each do |name|
      it "does not warn about '#{name}'" do
        ws = warnings_for(build_domain(name.to_sym))
        naming_ws = ws.select { |w| w.include?("vague suffix") || w.include?("redundant prefix") || w.include?("Hungarian") }
        expect(naming_ws).to be_empty
      end
    end
  end

  describe "does not produce errors" do
    it "returns no errors for bad attribute names" do
      domain = build_domain(:order_data)
      v = Hecks::Validator.new(domain)
      valid = v.valid?
      expect(valid).to be true
    end
  end
end

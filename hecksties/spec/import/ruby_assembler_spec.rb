require "spec_helper"
require "hecks_cli"

RSpec.describe Hecks::Import::RubyAssembler do
  describe "#assemble" do
    it "generates DSL from parsed classes" do
      parsed = [
        { name: "Order", module: nil, attributes: [{ name: "total", type: "String" }],
          nested_classes: [] }
      ]
      dsl = described_class.new(parsed, domain_name: "Shop").assemble
      expect(dsl).to include('Hecks.domain "Shop"')
      expect(dsl).to include('aggregate "Order"')
      expect(dsl).to include("attribute :total, String")
    end

    it "groups classes by module into aggregates" do
      parsed = [
        { name: "Invoice", module: "Billing", attributes: [{ name: "amount", type: "String" }],
          nested_classes: [] },
        { name: "LineItem", module: "Billing", attributes: [{ name: "desc", type: "String" }],
          nested_classes: [] }
      ]
      dsl = described_class.new(parsed, domain_name: "Acme").assemble
      expect(dsl).to include('aggregate "Billing"')
      expect(dsl).to include('value_object "LineItem"')
      expect(dsl).to include("attribute :amount, String")
    end

    it "generates Create commands for root aggregates" do
      parsed = [
        { name: "Widget", module: nil, attributes: [{ name: "size", type: "String" }],
          nested_classes: [] }
      ]
      dsl = described_class.new(parsed, domain_name: "Factory").assemble
      expect(dsl).to include('command "CreateWidget"')
    end

    it "renders nested classes as value objects" do
      parsed = [
        { name: "Order", module: nil,
          attributes: [{ name: "total", type: "String" }],
          nested_classes: [
            { name: "Address", attributes: [{ name: "street", type: "String" }], nested_classes: [] }
          ] }
      ]
      dsl = described_class.new(parsed, domain_name: "Shop").assemble
      expect(dsl).to include('value_object "Address"')
      expect(dsl).to include("attribute :street, String")
    end
  end
end

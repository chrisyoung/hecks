# breaking_classifier_spec.rb — HEC-100
#
# Specs for new breaking change kinds: change_attribute_type,
# rename_attribute, add_required_command_attribute.
#
require "spec_helper"

RSpec.describe Hecks::DomainVersioning::BreakingClassifier do
  Change = Hecks::Migrations::DomainDiff::Change

  describe ".breaking?" do
    it "classifies :change_attribute_type as breaking" do
      change = Change.new(kind: :change_attribute_type, context: nil, aggregate: "Widget",
                          details: { name: :color, old_type: "String", new_type: "Integer" })
      expect(described_class.breaking?(change)).to be true
    end

    it "classifies :rename_attribute as breaking" do
      change = Change.new(kind: :rename_attribute, context: nil, aggregate: "Widget",
                          details: { old_name: :color, new_name: :colour })
      expect(described_class.breaking?(change)).to be true
    end

    it "classifies :add_required_command_attribute as breaking" do
      change = Change.new(kind: :add_required_command_attribute, context: nil, aggregate: "Widget",
                          details: { command: "CreateWidget", name: :priority })
      expect(described_class.breaking?(change)).to be true
    end

    it "classifies :add_attribute as non-breaking" do
      change = Change.new(kind: :add_attribute, context: nil, aggregate: "Widget",
                          details: { name: :tags, type: "String" })
      expect(described_class.breaking?(change)).to be false
    end
  end

  describe ".format_label" do
    it "formats change_attribute_type" do
      change = Change.new(kind: :change_attribute_type, context: nil, aggregate: "Widget",
                          details: { name: :color, old_type: "String", new_type: "Integer" })
      label = described_class.format_label(change)
      expect(label).to include("Widget.color")
      expect(label).to include("String -> Integer")
    end

    it "formats rename_attribute" do
      change = Change.new(kind: :rename_attribute, context: nil, aggregate: "Widget",
                          details: { old_name: :color, new_name: :colour })
      label = described_class.format_label(change)
      expect(label).to include("color -> colour")
    end

    it "formats add_required_command_attribute" do
      change = Change.new(kind: :add_required_command_attribute, context: nil, aggregate: "Widget",
                          details: { command: "CreateWidget", name: :priority })
      label = described_class.format_label(change)
      expect(label).to include("CreateWidget")
      expect(label).to include("priority")
    end
  end
end

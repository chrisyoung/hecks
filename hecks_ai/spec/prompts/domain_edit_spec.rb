require "spec_helper"

RSpec.describe Hecks::AI::Prompts::DomainEdit do
  describe "SYSTEM_PROMPT" do
    it "describes the domain editing role" do
      expect(described_class::SYSTEM_PROMPT).to include("domain modeler")
    end

    it "lists available operations" do
      expect(described_class::SYSTEM_PROMPT).to include("add_aggregate")
      expect(described_class::SYSTEM_PROMPT).to include("add_attribute")
      expect(described_class::SYSTEM_PROMPT).to include("add_command")
    end

    it "mentions PascalCase naming convention" do
      expect(described_class::SYSTEM_PROMPT).to include("PascalCase")
    end
  end

  describe "TOOL_SCHEMA" do
    subject(:schema) { described_class::TOOL_SCHEMA }

    it "is named edit_domain" do
      expect(schema[:name]).to eq("edit_domain")
    end

    it "requires operations array" do
      required = schema[:input_schema][:required]
      expect(required).to include("operations")
    end

    it "defines operation items with op enum" do
      items = schema[:input_schema][:properties][:operations][:items]
      ops = items[:properties][:op][:enum]
      expect(ops).to include("add_aggregate", "add_attribute", "remove_command")
    end
  end
end

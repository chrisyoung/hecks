require "spec_helper"

RSpec.describe ComplianceDomain::GovernancePolicy::Commands::CreatePolicy do
  describe "attributes" do
    subject(:command) { described_class.new(
          name: "example",
          description: "example",
          category: "example",
          framework_id: "example"
        ) }

    it "has name" do
      expect(command.name).to eq("example")
    end

    it "has description" do
      expect(command.description).to eq("example")
    end

    it "has category" do
      expect(command.category).to eq("example")
    end

    it "has framework_id" do
      expect(command.framework_id).to eq("example")
    end

  end

  describe "event" do
    it "emits CreatedPolicy" do
      expect(described_class.event_name).to eq("CreatedPolicy")
    end
  end
end

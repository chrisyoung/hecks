require "spec_helper"

RSpec.describe ComplianceDomain::RegulatoryFramework::Commands::RetireFramework do
  describe "attributes" do
    subject(:command) { described_class.new(framework_id: "example") }

    it "has framework_id" do
      expect(command.framework_id).to eq("example")
    end

  end

  describe "event" do
    it "emits RetiredFramework" do
      expect(described_class.event_name).to eq("RetiredFramework")
    end
  end
end

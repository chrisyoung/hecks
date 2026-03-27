require "spec_helper"

RSpec.describe ComplianceDomain::RegulatoryFramework::Commands::ActivateFramework do
  describe "attributes" do
    subject(:command) { described_class.new(framework_id: "example", effective_date: Date.today) }

    it "has framework_id" do
      expect(command.framework_id).to eq("example")
    end

    it "has effective_date" do
      expect(command.effective_date).to eq(Date.today)
    end

  end

  describe "event" do
    it "emits ActivatedFramework" do
      expect(described_class.event_name).to eq("ActivatedFramework")
    end
  end
end

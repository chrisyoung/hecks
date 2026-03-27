require "spec_helper"

RSpec.describe ModelRegistryDomain::DataUsageAgreement::Commands::CreateAgreement do
  describe "attributes" do
    subject(:command) { described_class.new(
          model_id: "example",
          data_source: "example",
          purpose: "example",
          consent_type: "example"
        ) }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

    it "has data_source" do
      expect(command.data_source).to eq("example")
    end

    it "has purpose" do
      expect(command.purpose).to eq("example")
    end

    it "has consent_type" do
      expect(command.consent_type).to eq("example")
    end

  end

  describe "event" do
    it "emits CreatedAgreement" do
      expect(described_class.event_name).to eq("CreatedAgreement")
    end
  end
end

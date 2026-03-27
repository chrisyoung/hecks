require "spec_helper"

RSpec.describe ComplianceDomain::TrainingRecord::Commands::RenewTraining do
  describe "attributes" do
    subject(:command) { described_class.new(
          training_record_id: "example",
          certification_id: "example",
          expires_at: Date.today
        ) }

    it "has training_record_id" do
      expect(command.training_record_id).to eq("example")
    end

    it "has certification_id" do
      expect(command.certification_id).to eq("example")
    end

    it "has expires_at" do
      expect(command.expires_at).to eq(Date.today)
    end

  end

  describe "event" do
    it "emits RenewedTraining" do
      expect(described_class.event_name).to eq("RenewedTraining")
    end
  end
end

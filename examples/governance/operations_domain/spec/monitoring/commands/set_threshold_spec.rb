require "spec_helper"

RSpec.describe OperationsDomain::Monitoring::Commands::SetThreshold do
  describe "attributes" do
    subject(:command) { described_class.new(monitoring_id: "example", threshold: 1.0) }

    it "has monitoring_id" do
      expect(command.monitoring_id).to eq("example")
    end

    it "has threshold" do
      expect(command.threshold).to eq(1.0)
    end

  end

  describe "event" do
    it "emits SetThreshold" do
      expect(described_class.event_name).to eq("SetThreshold")
    end
  end
end

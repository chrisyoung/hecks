require "spec_helper"

RSpec.describe OperationsDomain::Monitoring::Commands::RecordMetric do
  describe "attributes" do
    subject(:command) { described_class.new(
          model_id: "example",
          deployment_id: "example",
          metric_name: "example",
          value: 1.0,
          threshold: 1.0
        ) }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

    it "has deployment_id" do
      expect(command.deployment_id).to eq("example")
    end

    it "has metric_name" do
      expect(command.metric_name).to eq("example")
    end

    it "has value" do
      expect(command.value).to eq(1.0)
    end

    it "has threshold" do
      expect(command.threshold).to eq(1.0)
    end

  end

  describe "event" do
    it "emits RecordedMetric" do
      expect(described_class.event_name).to eq("RecordedMetric")
    end
  end
end

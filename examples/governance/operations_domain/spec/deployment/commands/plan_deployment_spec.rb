require "spec_helper"

RSpec.describe OperationsDomain::Deployment::Commands::PlanDeployment do
  describe "attributes" do
    subject(:command) { described_class.new(
          model_id: "example",
          environment: "example",
          endpoint: "example",
          purpose: "example",
          audience: "example"
        ) }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

    it "has environment" do
      expect(command.environment).to eq("example")
    end

    it "has endpoint" do
      expect(command.endpoint).to eq("example")
    end

    it "has purpose" do
      expect(command.purpose).to eq("example")
    end

    it "has audience" do
      expect(command.audience).to eq("example")
    end

  end

  describe "event" do
    it "emits PlannedDeployment" do
      expect(described_class.event_name).to eq("PlannedDeployment")
    end
  end
end

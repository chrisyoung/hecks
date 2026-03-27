require "spec_helper"

RSpec.describe OperationsDomain::Deployment::Commands::DeployModel do
  describe "attributes" do
    subject(:command) { described_class.new(deployment_id: "example") }

    it "has deployment_id" do
      expect(command.deployment_id).to eq("example")
    end

  end

  describe "event" do
    it "emits DeployedModel" do
      expect(described_class.event_name).to eq("DeployedModel")
    end
  end
end

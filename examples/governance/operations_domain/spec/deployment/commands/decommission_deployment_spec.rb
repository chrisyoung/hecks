require "spec_helper"

RSpec.describe OperationsDomain::Deployment::Commands::DecommissionDeployment do
  describe "attributes" do
    subject(:command) { described_class.new(deployment_id: "example") }

    it "has deployment_id" do
      expect(command.deployment_id).to eq("example")
    end

  end

  describe "event" do
    it "emits DecommissionedDeployment" do
      expect(described_class.event_name).to eq("DecommissionedDeployment")
    end
  end
end

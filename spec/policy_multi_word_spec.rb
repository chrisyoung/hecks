require "spec_helper"

RSpec.describe "Policy dispatch with multi-word aggregate names" do
  let(:domain) do
    Hecks.domain "GovTest" do
      aggregate "AiModel" do
        attribute :name, String
        attribute :risk_level, String

        command "RegisterAiModel" do
          attribute :name, String
        end

        command "ClassifyAiModel" do
          attribute :model_id, String
          attribute :risk_level, String
        end

        policy "AutoClassify" do
          on "RegisteredAiModel"
          trigger "ClassifyAiModel"
          defaults risk_level: "low"
        end
      end
    end
  end

  before { @app = Hecks.load(domain) }

  it "policy triggers command on multi-word aggregate" do
    AiModel.register(name: "GPT-5")
    events = @app.events.map { |e| e.class.name.split("::").last }
    expect(events).to include("ClassifiedAiModel")
  end
end

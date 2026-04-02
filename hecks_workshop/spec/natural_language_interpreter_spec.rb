require "spec_helper"

RSpec.describe Hecks::Workshop::NaturalLanguageInterpreter do
  let(:runner) { Hecks::Workshop::WorkshopRunner.new }
  let(:fake_client) { instance_double(Hecks::AI::LlmClient) }

  before do
    allow($stdout).to receive(:puts)
    runner.instance_variable_set(:@workshop, Hecks::Workshop.new("Test"))
  end

  subject(:interpreter) { described_class.new(runner, client: fake_client) }

  describe "#available?" do
    it "returns true when client is present" do
      expect(interpreter.available?).to be true
    end

    it "returns false when client is nil" do
      no_key = described_class.new(runner, client: nil)
      expect(no_key.available?).to be false
    end
  end

  describe "#interpret" do
    context "without API key" do
      subject(:interpreter) { described_class.new(runner, client: nil) }

      it "prints a helpful message and returns nil" do
        expect(interpreter.interpret("add a name to Pizza")).to be_nil
      end
    end

    context "with a working client" do
      let(:operations) do
        [
          { op: "add_aggregate", name: "Pizza" },
          { op: "add_attribute", aggregate: "Pizza", name: "name", type: "String" }
        ]
      end

      let(:api_response) do
        {
          content: [
            { type: "tool_use", id: "toolu_01", name: "edit_domain",
              input: { operations: operations } }
          ]
        }
      end

      before do
        allow(fake_client).to receive(:send).with(:post, anything).and_return(api_response)
        allow(fake_client).to receive(:send).with(:extract_tool_result, api_response).and_return(api_response[:content].first[:input])
        stub_const("Hecks::AI::LlmClient::MODEL", "test-model")
        stub_const("Hecks::AI::LlmClient::MAX_TOKENS", 1024)
        allow(fake_client).to receive(:class).and_return(Hecks::AI::LlmClient)
      end

      it "returns the list of operations" do
        result = interpreter.interpret("create a Pizza with a name")
        expect(result.size).to eq(2)
        expect(result.first[:op]).to eq("add_aggregate")
      end

      it "applies the operations to the runner" do
        interpreter.interpret("create a Pizza with a name")
        expect(runner.aggregates).to include("Pizza")
      end
    end

    context "when LLM returns an error" do
      before do
        allow(fake_client).to receive(:send).with(:post, anything)
          .and_raise(RuntimeError, "API timeout")
        stub_const("Hecks::AI::LlmClient::MODEL", "test-model")
        stub_const("Hecks::AI::LlmClient::MAX_TOKENS", 1024)
        allow(fake_client).to receive(:class).and_return(Hecks::AI::LlmClient)
      end

      it "prints error and returns nil" do
        expect(interpreter.interpret("do something")).to be_nil
      end
    end
  end

  describe "operation application" do
    let(:operations) do
      [{ op: "add_aggregate", name: "Order" }]
    end

    let(:api_response) do
      {
        content: [
          { type: "tool_use", id: "toolu_01", name: "edit_domain",
            input: { operations: operations } }
        ]
      }
    end

    before do
      allow(fake_client).to receive(:send).with(:post, anything).and_return(api_response)
      allow(fake_client).to receive(:send).with(:extract_tool_result, api_response).and_return(api_response[:content].first[:input])
      stub_const("Hecks::AI::LlmClient::MODEL", "test-model")
      stub_const("Hecks::AI::LlmClient::MAX_TOKENS", 1024)
      allow(fake_client).to receive(:class).and_return(Hecks::AI::LlmClient)
    end

    it "creates aggregates via add_aggregate" do
      interpreter.interpret("add an order")
      expect(runner.aggregates).to include("Order")
    end
  end

  describe "#format_operation" do
    it "formats add_aggregate" do
      op = { op: "add_aggregate", name: "Pizza" }
      result = interpreter.send(:format_operation, op)
      expect(result).to eq("Create aggregate Pizza")
    end

    it "formats add_attribute" do
      op = { op: "add_attribute", aggregate: "Pizza", name: "name", type: "String" }
      result = interpreter.send(:format_operation, op)
      expect(result).to eq("Add name (String) to Pizza")
    end

    it "formats remove_aggregate" do
      op = { op: "remove_aggregate", name: "Pizza" }
      result = interpreter.send(:format_operation, op)
      expect(result).to eq("Remove aggregate Pizza")
    end
  end

  after do
    Hecks::Utils.remove_constant(:Pizza, from: Hecks::Workshop::WorkshopRunner)
    Hecks::Utils.remove_constant(:Order, from: Hecks::Workshop::WorkshopRunner)
  end
end

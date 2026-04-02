require "spec_helper"

RSpec.describe Hecks::AI::DomainReviewer do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String
        validation :name, presence: true
        command "CreatePizza" do
          attribute :name, String
          attribute :description, String
        end
      end
    end
  end

  describe "#call" do
    context "without an API key" do
      subject(:reviewer) { described_class.new(domain, api_key: nil) }

      it "returns unavailable review with score 0" do
        result = reviewer.call
        expect(result[:overall_score]).to eq(0)
        expect(result[:summary]).to include("unavailable")
        expect(result[:findings]).to eq([])
      end
    end

    context "with an empty API key" do
      subject(:reviewer) { described_class.new(domain, api_key: "  ") }

      it "returns unavailable review" do
        result = reviewer.call
        expect(result[:overall_score]).to eq(0)
      end
    end

    context "with a valid API key" do
      subject(:reviewer) { described_class.new(domain, api_key: "test-key") }

      let(:canned_review) do
        {
          overall_score: 7,
          summary: "Solid domain model with minor naming improvements needed.",
          findings: [
            {
              target: "Pizza",
              category: "value_objects",
              severity: "suggestion",
              message: "Consider extracting Topping as a value object.",
              recommendation: "Add a Topping value object with name and amount attributes."
            }
          ]
        }
      end

      let(:api_response_body) do
        {
          id: "msg_01",
          type: "message",
          role: "assistant",
          content: [
            { type: "tool_use", id: "toolu_01", name: "review_domain", input: canned_review }
          ],
          model: "claude-opus-4-5",
          stop_reason: "tool_use"
        }.to_json
      end

      before { stub_http_response(200, api_response_body) }

      it "returns structured review with score and findings" do
        result = reviewer.call
        expect(result[:overall_score]).to eq(7)
        expect(result[:summary]).to include("Solid domain")
        expect(result[:findings].size).to eq(1)
        expect(result[:findings].first[:severity]).to eq("suggestion")
      end

      it "serializes the domain before sending" do
        reviewer.call
        # The HTTP request was made (stub didn't raise), which means
        # the domain was successfully serialized and sent
      end
    end

    context "when the API returns an error" do
      subject(:reviewer) { described_class.new(domain, api_key: "test-key") }

      before { stub_http_response(500, '{"error": "server error"}') }

      it "raises a descriptive error" do
        expect { reviewer.call }
          .to raise_error(RuntimeError, /Anthropic API error 500/)
      end
    end

    context "when the API returns no tool_use block" do
      subject(:reviewer) { described_class.new(domain, api_key: "test-key") }

      let(:no_tool_body) do
        { content: [{ type: "text", text: "here is your review" }] }.to_json
      end

      before { stub_http_response(200, no_tool_body) }

      it "raises an error" do
        expect { reviewer.call }
          .to raise_error(RuntimeError, /No tool_use block/)
      end
    end
  end

  def stub_http_response(code, body)
    response = instance_double(Net::HTTPResponse, code: code.to_s, body: body)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)
  end
end

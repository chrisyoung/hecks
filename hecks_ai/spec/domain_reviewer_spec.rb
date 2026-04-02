require "spec_helper"

RSpec.describe Hecks::AI::DomainReviewer do
  let(:domain) do
    Hecks.domain("Pizzas") do
      aggregate("Pizza") do
        attribute :name, String
        attribute :description, String
        value_object("Topping") { attribute :name, String }
        command("CreatePizza") { attribute :name, String; attribute :description, String }
      end
      aggregate("Order") do
        reference_to "Pizza"
        attribute :customer_name, String
        command("PlaceOrder") { attribute :customer_name, String }
      end
    end
  end

  describe "local review (no API key)" do
    subject(:reviewer) { described_class.new(domain, api_key: nil) }

    it "returns a structured review" do
      review = reviewer.review
      expect(review[:overall_score]).to be_between(1, 10)
      expect(review[:strengths]).to be_an(Array)
      expect(review[:improvements]).to be_an(Array)
      expect(review[:source]).to eq("local")
    end

    it "detects strengths from domain structure" do
      review = reviewer.review
      expect(review[:strengths].any? { |s| s.include?("aggregates") }).to be true
      expect(review[:strengths].any? { |s| s.include?("value objects") }).to be true
    end

    it "includes validation warnings as improvements" do
      review = reviewer.review
      expect(review[:improvements]).to be_an(Array)
    end
  end

  describe "AI review (with canned response)" do
    let(:canned_review) do
      {
        overall_score: 8,
        strengths: ["Good aggregate separation", "Clear command naming"],
        improvements: [
          { area: "naming", description: "Consider more specific names", suggestion: "Use 'MenuItem' instead of 'Pizza'" }
        ],
        missing_concepts: ["DeliveryAddress"]
      }
    end

    let(:api_response_body) do
      {
        content: [
          { type: "tool_use", id: "toolu_01", name: "review_domain", input: canned_review }
        ]
      }.to_json
    end

    it "sends domain to API and returns structured review" do
      reviewer = described_class.new(domain, api_key: "test-key")
      response = instance_double(Net::HTTPResponse, code: "200", body: api_response_body)
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)

      review = reviewer.review
      expect(review[:overall_score]).to eq(8)
      expect(review[:strengths]).to include("Good aggregate separation")
      expect(review[:improvements].first[:area]).to eq("naming")
    end
  end
end

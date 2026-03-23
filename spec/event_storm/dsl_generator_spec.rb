require "spec_helper"

RSpec.describe Hecks::EventStorm::DslGenerator do
  let(:source) do
    <<~STORM
      ## Bounded Context: Ordering

      Command: [Place Order]
        Aggregate: (Order)
        ReadModel: <Menu & Availability>
      Event: >>Order Placed<<

      Command: [Process Payment]
        Aggregate: (Payment)
        External: [[Stripe]]
      Event: >>Payment Processed<<

      Policy: {When Order Placed, Start Payment}
    STORM
  end

  let(:parse_result) { Hecks::EventStorm::Parser.new(source).parse }
  subject(:dsl) { described_class.new(parse_result, name: "PizzaOrdering").generate }

  it "generates valid DSL with domain name" do
    expect(dsl).to include('Hecks.domain "PizzaOrdering" do')
  end

  it "generates bounded context blocks" do
    expect(dsl).to include('context "Ordering" do')
  end

  it "generates aggregate blocks" do
    expect(dsl).to include('aggregate "Order" do')
    expect(dsl).to include('aggregate "Payment" do')
  end

  it "generates command blocks with TODO" do
    expect(dsl).to include('command "PlaceOrder" do')
    expect(dsl).to include("# TODO: add attributes")
  end

  it "includes read_model DSL calls" do
    expect(dsl).to include('read_model "Menu & Availability"')
  end

  it "includes external DSL calls" do
    expect(dsl).to include('external "Stripe"')
  end

  it "generates policy blocks" do
    expect(dsl).to include('policy "StartPayment" do')
    expect(dsl).to include('on "OrderPlaced"')
    expect(dsl).to include('trigger "StartPayment"')
  end

  it "generates parseable Ruby DSL" do
    domain = eval(dsl)
    expect(domain).to be_a(Hecks::DomainModel::Structure::Domain)
    expect(domain.name).to eq("PizzaOrdering")
  end
end

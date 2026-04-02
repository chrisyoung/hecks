require "spec_helper"
require "hecks/extensions/policy_tracing"

RSpec.describe "HecksPolicyTracing extension" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :status, String

        command "CreatePizza" do
          attribute :name, String
        end

        command "MarkReady" do
          attribute :name, String
        end

        policy "AutoReady" do
          on "CreatedPizza"
          trigger "MarkReady"
        end
      end
    end
  end

  it "records policy traces when policies fire" do
    app = Hecks.load(domain)
    app.extend(:policy_tracing)

    PizzasDomain::Pizza.create(name: "Margherita")

    traces = Hecks.policy_traces
    expect(traces.size).to eq(1)
    expect(traces.first[:policy]).to eq("AutoReady")
    expect(traces.first[:event]).to eq("CreatedPizza")
    expect(traces.first[:condition_met]).to be true
    expect(traces.first[:timestamp]).to be_a(Time)
  end

  it "clears traces on demand" do
    app = Hecks.load(domain)
    app.extend(:policy_tracing)

    PizzasDomain::Pizza.create(name: "Test")
    expect(Hecks.policy_traces.size).to eq(1)

    Hecks.clear_policy_traces
    expect(Hecks.policy_traces).to be_empty
  end
end

require "spec_helper"
require "hecks/extensions/tracing"

RSpec.describe "HecksTracing extension" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  after { Hecks.trace_id = nil }

  it "stamps trace_id on published events" do
    app = Hecks.load(domain)
    app.extend(:tracing)
    Hecks.trace_id = "abc-123"

    PizzasDomain::Pizza.create(name: "Margherita")

    event = app.events.last
    expect(Hecks.event_trace_id(event)).to eq("abc-123")
  end

  it "returns nil when no trace_id is set" do
    app = Hecks.load(domain)
    app.extend(:tracing)

    PizzasDomain::Pizza.create(name: "Plain")

    event = app.events.last
    expect(Hecks.event_trace_id(event)).to be_nil
  end

  it "supports with_trace block scoping" do
    app = Hecks.load(domain)
    app.extend(:tracing)

    Hecks.with_trace("req-1") do
      PizzasDomain::Pizza.create(name: "Scoped")
    end

    expect(Hecks.event_trace_id(app.events.last)).to eq("req-1")
    expect(Hecks.trace_id).to be_nil
  end
end

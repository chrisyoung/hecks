require "spec_helper"
require "hecks/extensions/policy_tracing"

RSpec.describe "Policy tracing extension" do
  let(:domain) do
    Hecks.domain "TracingTest" do
      aggregate "Order" do
        attribute :total, Float

        command "PlaceOrder" do
          attribute :total, Float
        end

        command "NotifyWarehouse" do
          attribute :total, Float
        end

        command "FlagHighValue" do
          attribute :total, Float
        end

        policy "ShipNotification" do
          on "PlacedOrder"
          trigger "NotifyWarehouse"
        end

        policy "HighValueAlert" do
          on "PlacedOrder"
          trigger "FlagHighValue"
          condition { |event| event.total > 1000 }
        end
      end
    end
  end

  it "records a trace for each policy execution" do
    app = Hecks.load(domain, force: true)
    app.extend(:policy_tracing)

    app.run("PlaceOrder", total: 500.0)

    traces = Hecks.policy_traces
    expect(traces.size).to eq(2)
  end

  it "captures policy name, event, action, and timestamp" do
    app = Hecks.load(domain, force: true)
    app.extend(:policy_tracing)

    app.run("PlaceOrder", total: 500.0)

    trace = Hecks.policy_traces.find { |t| t[:policy] == "ShipNotification" }
    expect(trace[:event]).to eq("PlacedOrder")
    expect(trace[:action]).to eq("NotifyWarehouse")
    expect(trace[:timestamp]).to be_a(Time)
    expect(trace[:duration_ms]).to be_a(Float)
  end

  it "records condition_result true when condition passes" do
    app = Hecks.load(domain, force: true)
    app.extend(:policy_tracing)

    app.run("PlaceOrder", total: 2000.0)

    trace = Hecks.policy_traces.find { |t| t[:policy] == "HighValueAlert" }
    expect(trace[:condition_result]).to be true
  end

  it "records condition_result false when condition fails" do
    app = Hecks.load(domain, force: true)
    app.extend(:policy_tracing)

    app.run("PlaceOrder", total: 50.0)

    trace = Hecks.policy_traces.find { |t| t[:policy] == "HighValueAlert" }
    expect(trace[:condition_result]).to be false
  end

  it "records condition_result true for policies without conditions" do
    app = Hecks.load(domain, force: true)
    app.extend(:policy_tracing)

    app.run("PlaceOrder", total: 50.0)

    trace = Hecks.policy_traces.find { |t| t[:policy] == "ShipNotification" }
    expect(trace[:condition_result]).to be true
  end

  it "exposes traces via Hecks.policy_traces" do
    app = Hecks.load(domain, force: true)
    app.extend(:policy_tracing)

    expect(Hecks.policy_traces).to eq([])

    app.run("PlaceOrder", total: 100.0)

    expect(Hecks.policy_traces).not_to be_empty
  end
end

require "spec_helper"
require "hecks/extensions/tracing"

RSpec.describe "Tracing extension" do
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

  describe "auto-generated trace ID" do
    it "assigns a UUID trace ID when none is set" do
      app = Hecks.load(domain)
      Hecks.extension_registry[:tracing]&.call(
        Object.const_get("PizzasDomain"), domain, app
      )

      PizzasDomain::Pizza.create(name: "Margherita")

      event = app.event_bus.events.last
      trace = event.instance_variable_get(:@_trace_id)
      expect(trace).to match(/\A[0-9a-f\-]{36}\z/)
    end

    it "generates a different trace ID per command dispatch" do
      app = Hecks.load(domain)
      Hecks.extension_registry[:tracing]&.call(
        Object.const_get("PizzasDomain"), domain, app
      )

      PizzasDomain::Pizza.create(name: "A")
      PizzasDomain::Pizza.create(name: "B")

      traces = app.event_bus.events.map { |e| e.instance_variable_get(:@_trace_id) }
      expect(traces.compact.size).to eq(2)
      expect(traces[0]).not_to eq(traces[1])
    end
  end

  describe "preserving pre-set trace ID" do
    it "uses the existing trace ID when one is already set" do
      app = Hecks.load(domain)
      Hecks.extension_registry[:tracing]&.call(
        Object.const_get("PizzasDomain"), domain, app
      )
      Hecks.trace_id = "incoming-trace-abc"

      PizzasDomain::Pizza.create(name: "Pepperoni")

      event = app.event_bus.events.last
      trace = event.instance_variable_get(:@_trace_id)
      expect(trace).to eq("incoming-trace-abc")
    end
  end

  describe "thread context" do
    it "provides trace_id accessors" do
      Hecks.trace_id = "test-123"
      expect(Hecks.trace_id).to eq("test-123")
    end

    it "with_trace scopes trace ID and yields it" do
      yielded = nil
      Hecks.with_trace("scoped-id") { |id| yielded = id }
      expect(yielded).to eq("scoped-id")
      expect(Hecks.trace_id).to be_nil
    end

    it "with_trace auto-generates UUID when called without argument" do
      yielded = nil
      Hecks.with_trace { |id| yielded = id }
      expect(yielded).to match(/\A[0-9a-f\-]{36}\z/)
    end
  end
end

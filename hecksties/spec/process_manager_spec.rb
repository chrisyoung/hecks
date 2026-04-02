require "spec_helper"

RSpec.describe "Process Manager (HEC-67)" do
  let(:domain) do
    Hecks.domain "ProcessManagerTest" do
      aggregate "Order" do
        attribute :item, String
        attribute :status, String
        attribute :correlation_id, String

        command "PlaceOrder" do
          attribute :item, String
          attribute :correlation_id, String
        end

        command "ShipOrder" do
          attribute :item, String
          attribute :correlation_id, String
        end

        command "CompleteOrder" do
          attribute :item, String
          attribute :correlation_id, String
        end
      end

      saga "OrderProcess" do
        on "OrderPlaced",
          dispatch: "ShipOrder",
          from: "started",
          to: "shipping"

        on "OrderShipped",
          dispatch: "CompleteOrder",
          from: "shipping",
          to: "completed"
      end
    end
  end

  before { @app = Hecks.load(domain) }

  describe "DSL and IR" do
    it "registers event-driven transitions in the saga IR" do
      saga = domain.sagas.first
      expect(saga.transitions.size).to eq(2)
      expect(saga.event_driven?).to be true
      expect(saga.steps).to be_empty
    end

    it "builds transition IR with all attributes" do
      t = domain.sagas.first.transitions.first
      expect(t).to be_a(Hecks::DomainModel::Behavior::SagaTransition)
      expect(t.event).to eq("OrderPlaced")
      expect(t.command).to eq("ShipOrder")
      expect(t.from).to eq("started")
      expect(t.to).to eq("shipping")
      expect(t.guarded?).to be true
    end
  end

  describe "runtime wiring" do
    it "exposes start_<saga_name> method on the domain module" do
      expect(ProcessManagerTestDomain).to respond_to(:start_order_process)
    end

    it "starts a process manager instance with initial state" do
      result = ProcessManagerTestDomain.start_order_process(
        correlation_id: "order-1", item: "Widget"
      )
      expect(result[:state]).to eq("started")
      expect(result[:correlation_id]).to eq("order-1")
      expect(result[:saga_name]).to eq("OrderProcess")
    end
  end

  describe "event-driven transitions" do
    it "transitions state when matching event fires" do
      instance = ProcessManagerTestDomain.start_order_process(
        correlation_id: "order-2", item: "Gadget"
      )

      # Simulate the OrderPlaced event
      event = Struct.new(:correlation_id, keyword_init: true)
        .new(correlation_id: "order-2")
      @app.event_bus.publish(event)

      # Allow the class to match "OrderPlaced" by naming
      # Instead, use a proper event class
      order_placed = Class.new do
        attr_reader :correlation_id
        def initialize(cid); @correlation_id = cid; end
        def self.name; "ProcessManagerTestDomain::Order::OrderPlaced"; end
      end

      @app.event_bus.publish(order_placed.new("order-2"))

      store = @app.instance_variable_get(:@saga_store)
      updated = store.find_by_correlation("order-2")
      expect(updated[:state]).to eq("shipping")
      expect(updated[:completed_transitions]).to include("OrderPlaced")
    end

    it "guards transitions by from-state" do
      ProcessManagerTestDomain.start_order_process(
        correlation_id: "order-3", item: "Gizmo"
      )

      # Publish OrderShipped when state is "started" (wrong state)
      order_shipped = Class.new do
        attr_reader :correlation_id
        def initialize(cid); @correlation_id = cid; end
        def self.name; "ProcessManagerTestDomain::Order::OrderShipped"; end
      end

      @app.event_bus.publish(order_shipped.new("order-3"))

      store = @app.instance_variable_get(:@saga_store)
      instance = store.find_by_correlation("order-3")
      # Should still be "started" because OrderShipped requires from: "shipping"
      expect(instance[:state]).to eq("started")
    end
  end

  describe "SagaStore#find_by_correlation" do
    it "finds by correlation_id in instance metadata" do
      store = Hecks::SagaStore.new
      store.save("pm_abc", {
        saga_id: "pm_abc",
        correlation_id: "corr-99",
        attrs: { item: "X" }
      })
      found = store.find_by_correlation("corr-99")
      expect(found[:saga_id]).to eq("pm_abc")
    end

    it "finds by correlation_id in attrs" do
      store = Hecks::SagaStore.new
      store.save("pm_def", {
        saga_id: "pm_def",
        attrs: { correlation_id: "corr-77" }
      })
      found = store.find_by_correlation("corr-77")
      expect(found[:saga_id]).to eq("pm_def")
    end

    it "returns nil when not found" do
      store = Hecks::SagaStore.new
      expect(store.find_by_correlation("nonexistent")).to be_nil
    end
  end

  describe "backward compatibility" do
    let(:imperative_domain) do
      Hecks.domain "ImperativeSagaCompat" do
        aggregate "Task" do
          attribute :name, String
          command "DoStep" do
            attribute :name, String
          end
        end

        saga "SimpleFlow" do
          step "DoStep", on_success: "StepDone"
        end
      end
    end

    before { @compat_app = Hecks.load(imperative_domain) }

    it "still supports imperative step-based sagas" do
      saga = imperative_domain.sagas.first
      expect(saga.event_driven?).to be false
      expect(saga.steps.size).to eq(1)
    end

    it "wires imperative sagas as start_ methods" do
      result = ImperativeSagaCompatDomain.start_simple_flow(name: "test")
      expect(result[:state]).to eq(:completed)
    end
  end

  describe "mixed saga with both steps and transitions" do
    let(:mixed_domain) do
      Hecks.domain "MixedSagaTest" do
        aggregate "Ticket" do
          attribute :title, String
          attribute :correlation_id, String

          command "CreateTicket" do
            attribute :title, String
            attribute :correlation_id, String
          end

          command "AssignTicket" do
            attribute :title, String
            attribute :correlation_id, String
          end
        end

        saga "TicketProcess" do
          step "CreateTicket", on_success: "TicketCreated"

          on "TicketCreated",
            dispatch: "AssignTicket",
            from: "started",
            to: "assigned"
        end
      end
    end

    it "has both steps and transitions" do
      d = mixed_domain
      saga = d.sagas.first
      expect(saga.steps.size).to eq(1)
      expect(saga.transitions.size).to eq(1)
      expect(saga.event_driven?).to be true
    end
  end
end

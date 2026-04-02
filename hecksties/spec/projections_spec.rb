require "spec_helper"

RSpec.describe "Projections (HEC-64)" do
  describe "ProjectionRebuilder" do
    it "replays events through projection functions" do
      event_class = Struct.new(:quantity, keyword_init: true) do
        def self.name; "TestDomain::PlacedOrder"; end
      end

      events = [
        event_class.new(quantity: 3),
        event_class.new(quantity: 2)
      ]

      projections = {
        "PlacedOrder" => proc { |event, state|
          count = (state[:total] || 0) + event.quantity
          state.merge(total: count)
        }
      }

      result = Hecks::ProjectionRebuilder.replay(events, projections)
      expect(result[:total]).to eq(5)
    end

    it "skips events with no matching projection" do
      event_class = Struct.new(:data, keyword_init: true) do
        def self.name; "TestDomain::UnknownEvent"; end
      end

      events = [event_class.new(data: "ignored")]
      projections = {}

      result = Hecks::ProjectionRebuilder.replay(events, projections)
      expect(result).to eq({})
    end

    it "starts from initial_state when provided" do
      result = Hecks::ProjectionRebuilder.replay([], {}, initial_state: { count: 10 })
      expect(result[:count]).to eq(10)
    end
  end

  describe "from_stream DSL" do
    let(:domain) do
      Hecks.domain "ProjectionTest" do
        aggregate "Order" do
          attribute :item, String
          attribute :quantity, Integer

          command "PlaceOrder" do
            attribute :item, String
            attribute :quantity, Integer
          end
        end

        view "OrderSummary" do
          from_stream "orders"

          project("PlacedOrder") do |event, state|
            count = (state[:total_orders] || 0) + 1
            qty = (state[:total_quantity] || 0) + event.quantity
            state.merge(total_orders: count, total_quantity: qty)
          end
        end
      end
    end

    it "stores stream name on the read model IR" do
      view = domain.views.first
      expect(view.stream).to eq("orders")
    end

    it "stream defaults to nil when not declared" do
      d = Hecks.domain "NoStreamTest" do
        aggregate "Item" do
          attribute :name, String
          command "CreateItem" do
            attribute :name, String
          end
        end

        view "ItemCount" do
          project("CreatedItem") { |_event, state| state.merge(count: (state[:count] || 0) + 1) }
        end
      end

      expect(d.views.first.stream).to be_nil
    end
  end

  describe "ViewBinding with event replay" do
    let(:domain) do
      Hecks.domain "ReplayTest" do
        aggregate "Order" do
          attribute :item, String
          attribute :quantity, Integer

          command "PlaceOrder" do
            attribute :item, String
            attribute :quantity, Integer
          end
        end

        view "OrderTotals" do
          from_stream "orders"

          project("PlacedOrder") do |event, state|
            qty = (state[:total_quantity] || 0) + event.quantity
            state.merge(total_quantity: qty)
          end
        end
      end
    end

    before do
      @app = Hecks.load(domain)
    end

    it "projects live events after boot" do
      Order.place(item: "Widget", quantity: 5)
      expect(ReplayTestDomain::OrderTotals.current[:total_quantity]).to eq(5)
    end

    it "replays historical events when view is rebound" do
      # Place orders to build up event history
      Order.place(item: "A", quantity: 3)
      Order.place(item: "B", quantity: 7)

      # Capture events, then bind a fresh view with replay
      events = @app.event_bus.events.dup
      view = domain.views.first
      mod = ReplayTestDomain

      # Remove old constant so we can rebind
      mod.send(:remove_const, :OrderTotals) if mod.const_defined?(:OrderTotals)

      fresh_bus = Hecks::EventBus.new
      Hecks::ViewBinding.bind(view, fresh_bus, mod, event_store: events)

      # State should reflect replayed events without any new live events
      expect(ReplayTestDomain::OrderTotals.current[:total_quantity]).to eq(10)
    end
  end
end

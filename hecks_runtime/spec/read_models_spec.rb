require "spec_helper"

RSpec.describe "Views (HEC-167)" do
  let(:domain) do
    Hecks.domain "ViewTest" do
      aggregate "Order" do
        attribute :item, String
        attribute :quantity, Integer

        command "PlaceOrder" do
          attribute :item, String
          attribute :quantity, Integer
        end
      end

      view "OrderSummary" do
        project("PlacedOrder") do |event, state|
          count = (state[:total_orders] || 0) + 1
          qty = (state[:total_quantity] || 0) + event.quantity
          state.merge(total_orders: count, total_quantity: qty)
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain)
  end

  it "registers views in the domain IR" do
    expect(domain.views.size).to eq(1)
    expect(domain.views.first.name).to eq("OrderSummary")
    expect(domain.views.first.projections).to have_key("PlacedOrder")
  end

  it "projects events into view state" do
    Order.place(item: "Widget", quantity: 3)
    Order.place(item: "Gadget", quantity: 2)

    summary = ViewTestDomain::OrderSummary.current
    expect(summary[:total_orders]).to eq(2)
    expect(summary[:total_quantity]).to eq(5)
  end

  it "starts with empty state" do
    expect(ViewTestDomain::OrderSummary.current).to eq({})
  end
end

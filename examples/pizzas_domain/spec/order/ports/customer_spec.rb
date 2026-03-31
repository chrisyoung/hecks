require "spec_helper"

RSpec.describe "Order :customer port" do
  before { @app = Hecks.load(domain, port: :customer, force: true) }

  it "allows .find" do
    expect { Order.find("nonexistent") }.not_to raise_error
  end

  it "allows .all" do
    expect { Order.all }.not_to raise_error
  end

  it "denies .count" do
    expect { Order.count }.to raise_error(Hecks::PortAccessDenied)
  end

  it "denies .place" do
    expect { Order.place(
          customer_name: "example",
          pizza: "example",
          quantity: 1
        ) }.to raise_error(Hecks::PortAccessDenied)
  end

  it "denies .cancel" do
    expect { Order.cancel(order: "ref-id-123") }.to raise_error(Hecks::PortAccessDenied)
  end

end

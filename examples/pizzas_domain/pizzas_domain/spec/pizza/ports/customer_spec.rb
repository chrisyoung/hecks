require "spec_helper"

RSpec.describe "Pizza :customer port" do
  before { @app = Hecks.load(domain, port: :customer, force: true) }

  it "allows .find" do
    expect { Pizza.find("nonexistent") }.not_to raise_error
  end

  it "allows .all" do
    expect { Pizza.all }.not_to raise_error
  end

  it "denies .count" do
    expect { Pizza.count }.to raise_error(Hecks::PortAccessDenied)
  end

  it "denies .create" do
    expect { Pizza.create(name: "example", description: "example") }.to raise_error(Hecks::PortAccessDenied)
  end

  it "denies .add_topping" do
    expect { Pizza.add_topping(
          pizza_id: "ref-id-123",
          name: "example",
          amount: 1
        ) }.to raise_error(Hecks::PortAccessDenied)
  end

end

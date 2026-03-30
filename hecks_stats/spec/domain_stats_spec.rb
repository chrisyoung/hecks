require "hecks"
require "hecks_stats"

RSpec.describe HecksStats::DomainStats do
  let(:domain) do
    Hecks.domain("TestShop") do
      actor "admin", description: "System admin"
      actor "customer"

      aggregate "Order" do
        attribute :total, Float
        reference_to "Customer"
        entity("LineItem") { attribute :qty, Integer }
        reference_to "LineItem"

        validation :total, presence: true
        invariant("total must be positive") { total > 0 }

        query("Recent") { where(status: "recent") }
        specification("Large") { |o| o.total > 100 }

        command "PlaceOrder" do
          attribute :total, Float
        end
      end

      aggregate "Customer" do
        attribute :name, String
        command("CreateCustomer") { attribute :name, String }
      end
    end
  end

  it "collects all domain metrics" do
    stats = described_class.new(domain).to_h
    expect(stats[:name]).to eq("TestShop")
    expect(stats[:aggregates]).to eq(2)
    expect(stats[:commands]).to eq(2)
    expect(stats[:events]).to eq(2)
    expect(stats[:actors]).to eq(["admin", "customer"])
    expect(stats[:queries]).to eq(1)
    expect(stats[:specifications]).to eq(1)
    expect(stats[:validations]).to eq(1)
    expect(stats[:invariants]).to eq(1)
    expect(stats[:entities]).to eq(1)
    expect(stats[:references][:aggregation]).to be >= 1
  end

  it "generates a readable summary" do
    summary = described_class.new(domain).summary
    expect(summary).to include("TestShop Domain")
    expect(summary).to include("Aggregates:")
    expect(summary).to include("Actors: admin, customer")
  end
end

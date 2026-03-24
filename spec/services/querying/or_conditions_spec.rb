require "spec_helper"

RSpec.describe "OR conditions" do
  let(:domain) do
    Hecks.domain "OrTest" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :price, Integer

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
          attribute :price, Integer
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain, force: true)
    repo = @app["Pizza"]
    Hecks::Services::Querying::AdHocQueries.bind(OrTestDomain::Pizza, repo)

    OrTestDomain::Pizza.create(name: "Margherita", style: "Classic", price: 12)
    OrTestDomain::Pizza.create(name: "Pepperoni", style: "Spicy", price: 15)
    OrTestDomain::Pizza.create(name: "Hawaiian", style: "Tropical", price: 14)
    OrTestDomain::Pizza.create(name: "Cheese", style: "Classic", price: 10)
  end

  it "returns union of two where conditions" do
    results = OrTestDomain::Pizza.where(style: "Classic").or(OrTestDomain::Pizza.where(style: "Tropical"))
    expect(results.map(&:name)).to contain_exactly("Margherita", "Cheese", "Hawaiian")
  end

  it "does not include records matching neither condition" do
    results = OrTestDomain::Pizza.where(style: "Classic").or(OrTestDomain::Pizza.where(style: "Tropical"))
    expect(results.map(&:name)).not_to include("Pepperoni")
  end

  it "chains order after or" do
    results = OrTestDomain::Pizza.where(style: "Classic").or(OrTestDomain::Pizza.where(style: "Tropical")).order(:name)
    expect(results.map(&:name)).to eq(["Cheese", "Hawaiian", "Margherita"])
  end

  it "chains limit after or" do
    results = OrTestDomain::Pizza.where(style: "Classic").or(OrTestDomain::Pizza.where(style: "Tropical")).order(:name).limit(2)
    expect(results.map(&:name)).to eq(["Cheese", "Hawaiian"])
  end

  it "works with operators in or branches" do
    builder = Hecks::Services::Querying::QueryBuilder.new(@app["Pizza"])
    results = builder.where(price: builder.gt(14)).or(builder.where(style: "Classic"))
    expect(results.map(&:name)).to contain_exactly("Margherita", "Cheese", "Pepperoni")
  end

  it "existing AND queries still work" do
    results = OrTestDomain::Pizza.where(style: "Classic").where(name: "Cheese")
    expect(results.map(&:name)).to eq(["Cheese"])
  end

  it "count works with or" do
    count = OrTestDomain::Pizza.where(style: "Classic").or(OrTestDomain::Pizza.where(style: "Tropical")).count
    expect(count).to eq(3)
  end

  it "exists? works with or" do
    expect(OrTestDomain::Pizza.where(style: "Classic").or(OrTestDomain::Pizza.where(style: "Tropical")).exists?).to be true
    expect(OrTestDomain::Pizza.where(style: "X").or(OrTestDomain::Pizza.where(style: "Y")).exists?).to be false
  end
end

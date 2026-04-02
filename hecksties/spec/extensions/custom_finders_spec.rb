require "spec_helper"

RSpec.describe "Custom finders" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :email, String

        command "CreatePizza" do
          attribute :name, String
          attribute :email, String
        end

        finder :email
        finder :slug, attribute: :name
      end
    end
  end

  it "adds find_by_<name> methods on the repository" do
    app = Hecks.load(domain)

    PizzasDomain::Pizza.create(name: "Margherita", email: "m@pizza.com")
    PizzasDomain::Pizza.create(name: "Pepperoni", email: "p@pizza.com")

    repo = app["Pizza"]
    found = repo.find_by_email("m@pizza.com")
    expect(found).not_to be_nil
    expect(found.name).to eq("Margherita")
  end

  it "supports custom attribute mapping" do
    app = Hecks.load(domain)

    PizzasDomain::Pizza.create(name: "Hawaiian", email: "h@pizza.com")

    repo = app["Pizza"]
    found = repo.find_by_slug("Hawaiian")
    expect(found).not_to be_nil
    expect(found.email).to eq("h@pizza.com")
  end

  it "returns nil when no match is found" do
    app = Hecks.load(domain)

    repo = app["Pizza"]
    expect(repo.find_by_email("missing@pizza.com")).to be_nil
  end

  it "stores finders on the aggregate IR" do
    expect(domain.aggregates.first.finders.size).to eq(2)
    expect(domain.aggregates.first.finders.first.name).to eq(:email)
    expect(domain.aggregates.first.finders.last.attribute).to eq(:name)
  end
end

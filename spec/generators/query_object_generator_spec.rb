require "spec_helper"

RSpec.describe Hecks::Generators::Domain::QueryObjectGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
        end
      end
    end
  end

  let(:aggregate) { domain.aggregates.first }
  subject(:generator) { described_class.new(aggregate, domain_module: "PizzasDomain") }

  describe "#generate" do
    let(:code) { generator.generate }

    it "generates a query module" do
      expect(code).to include("module PizzaQueries")
    end

    it "nests under Queries namespace" do
      expect(code).to include("module Queries")
    end

    it "generates by_ methods for scalar attributes" do
      expect(code).to include("def by_name(value)")
      expect(code).to include("where(name: value)")
      expect(code).to include("def by_style(value)")
      expect(code).to include("where(style: value)")
    end

    it "excludes list attributes" do
      expect(code).not_to include("by_toppings")
    end
  end

end

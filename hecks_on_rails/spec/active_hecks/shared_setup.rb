# Shared domain setup for active_hecks specs
require "spec_helper"
require "active_hecks"

RSpec.shared_context "active_hecks pizzas" do
  before(:all) do
    domain = Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end

    Hecks.load(domain)
    ActiveHecks.activate(PizzasDomain, domain: domain)
  end
end

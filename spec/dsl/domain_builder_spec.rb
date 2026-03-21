require "spec_helper"

RSpec.describe Hecks::DSL::DomainBuilder do
  describe "building a domain" do
    subject(:domain) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String
          attribute :description, String
          attribute :toppings, list_of("Topping")

          value_object "Topping" do
            attribute :name, String
            attribute :amount, Integer
          end

          validation :name, presence: true

          command "CreatePizza" do
            attribute :name, String
            attribute :description, String
          end

          command "AddTopping" do
            attribute :pizza_id, reference_to("Pizza")
            attribute :topping, String
          end
        end

        aggregate "Order" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer

          command "PlaceOrder" do
            attribute :pizza_id, reference_to("Pizza")
            attribute :quantity, Integer
          end

          policy "ReserveIngredients" do
            on "PlacedOrder"
            trigger "ReserveStock"
          end
        end
      end
    end

    it "builds a domain with the correct name" do
      expect(domain.name).to eq("Pizzas")
    end

    it "has two aggregates" do
      expect(domain.aggregates.size).to eq(2)
    end

    describe "Pizza aggregate" do
      let(:pizza) { domain.aggregates.first }

      it "has the correct name" do
        expect(pizza.name).to eq("Pizza")
      end

      it "has three attributes" do
        expect(pizza.attributes.size).to eq(3)
      end

      it "has a list attribute for toppings" do
        toppings_attr = pizza.attributes.find { |a| a.name == :toppings }
        expect(toppings_attr).to be_list
      end

      it "has one value object" do
        expect(pizza.value_objects.size).to eq(1)
        expect(pizza.value_objects.first.name).to eq("Topping")
      end

      it "has two commands" do
        expect(pizza.commands.size).to eq(2)
      end

      it "infers events from commands" do
        expect(pizza.events.size).to eq(2)
        expect(pizza.events.map(&:name)).to include("CreatedPizza", "AddedTopping")
      end

      it "has validations" do
        expect(pizza.validations.size).to eq(1)
      end
    end

    describe "Order aggregate" do
      let(:order) { domain.aggregates.last }

      it "has a reference attribute" do
        pizza_ref = order.attributes.find { |a| a.name == :pizza_id }
        expect(pizza_ref).to be_reference
      end

      it "has a policy" do
        expect(order.policies.size).to eq(1)
        policy = order.policies.first
        expect(policy.name).to eq("ReserveIngredients")
        expect(policy.event_name).to eq("PlacedOrder")
        expect(policy.trigger_command).to eq("ReserveStock")
      end
    end
  end
end

module PizzasDomain
  class Pizza
    module Events
      class AddedTopping
        attr_reader :aggregate_id, :pizza_id, :name, :amount, :description, :toppings, :occurred_at

        def initialize(aggregate_id: nil, pizza_id: nil, name: nil, amount: nil, description: nil, toppings: nil)
          @aggregate_id = aggregate_id
          @pizza_id = pizza_id
          @name = name
          @amount = amount
          @description = description
          @toppings = toppings
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

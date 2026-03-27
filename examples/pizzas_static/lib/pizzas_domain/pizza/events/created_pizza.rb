module PizzasDomain
  class Pizza
    module Events
      class CreatedPizza
        attr_reader :aggregate_id, :name, :description, :toppings, :occurred_at

        def initialize(aggregate_id: nil, name: nil, description: nil, toppings: nil)
          @aggregate_id = aggregate_id
          @name = name
          @description = description
          @toppings = toppings
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

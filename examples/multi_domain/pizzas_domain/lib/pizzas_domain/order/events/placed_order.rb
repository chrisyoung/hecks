module PizzasDomain
  class Order
    module Events
      class PlacedOrder
        attr_reader :aggregate_id, :pizza_id, :quantity, :occurred_at

        def initialize(aggregate_id: nil, pizza_id: nil, quantity: nil)
          @aggregate_id = aggregate_id
          @pizza_id = pizza_id
          @quantity = quantity
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

module PizzasDomain
  class Order
    module Events
      class PlacedOrder
        attr_reader :aggregate_id, :customer_name, :pizza_id, :quantity, :items, :status, :occurred_at

        def initialize(aggregate_id: nil, customer_name: nil, pizza_id: nil, quantity: nil, items: nil, status: nil)
          @aggregate_id = aggregate_id
          @customer_name = customer_name
          @pizza_id = pizza_id
          @quantity = quantity
          @items = items
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

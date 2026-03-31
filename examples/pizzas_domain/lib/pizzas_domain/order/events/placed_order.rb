module PizzasDomain
  class Order
    module Events
      class PlacedOrder
        attr_reader :aggregate_id, :customer_name, :pizza, :quantity, :items, :status, :occurred_at

        def initialize(aggregate_id: nil, customer_name: nil, pizza: nil, quantity: nil, items: nil, status: nil)
          @aggregate_id = aggregate_id
          @customer_name = customer_name
          @pizza = pizza
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

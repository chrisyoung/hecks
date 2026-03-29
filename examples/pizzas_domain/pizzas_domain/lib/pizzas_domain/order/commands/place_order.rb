module PizzasDomain
  class Order
    module Commands
      class PlaceOrder
        include Hecks::Command
        emits "PlacedOrder"

        attr_reader :customer_name
        attr_reader :pizza_id
        attr_reader :quantity

        def initialize(
          customer_name: nil,
          pizza_id: nil,
          quantity: nil
        )
          @customer_name = customer_name
          @pizza_id = pizza_id
          @quantity = quantity
        end

        def call
          Order.new(customer_name: customer_name, items: [OrderItem.new(pizza_id: pizza_id, quantity: quantity)])
        end
      end
    end
  end
end

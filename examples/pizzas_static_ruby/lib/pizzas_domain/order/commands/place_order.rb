module PizzasDomain
  class Order
    module Commands
      class PlaceOrder
        include PizzasDomain::Runtime::Command
        emits "PlacedOrder"

        attr_reader :customer_name
        attr_reader :pizza
        attr_reader :quantity

        def initialize(
          customer_name: nil,
          pizza: nil,
          quantity: nil
        )
          @customer_name = customer_name
          @pizza = pizza
          @quantity = quantity
        end

        def call
          Order.new(customer_name: customer_name, items: [OrderItem.new(pizza: pizza, quantity: quantity)])
        end
      end
    end
  end
end

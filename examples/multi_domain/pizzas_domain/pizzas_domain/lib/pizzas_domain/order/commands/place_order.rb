module PizzasDomain
  class Order
    module Commands
      class PlaceOrder
        include Hecks::Command
        emits "PlacedOrder"

        attr_reader :quantity, :pizza

        def initialize(quantity: nil, pizza: nil)
          @quantity = quantity
          @pizza = pizza
        end

        def call
          Order.new(quantity: quantity, pizza: pizza)
        end
      end
    end
  end
end

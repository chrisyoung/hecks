module PizzasDomain
  class Order
    module Commands
      class PlaceOrder
        include Hecks::Command
        emits "PlacedOrder"

        attr_reader :quantity, :pizza_id

        def initialize(quantity: nil, pizza_id: nil)
          @quantity = quantity
          @pizza_id = pizza_id
        end

        def call
          Order.new(pizza_id: pizza_id, quantity: quantity)
        end
      end
    end
  end
end

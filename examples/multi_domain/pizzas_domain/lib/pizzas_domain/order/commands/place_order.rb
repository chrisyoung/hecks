module PizzasDomain
  class Order
    module Commands
      class PlaceOrder
        emits "PlacedOrder"

        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
        end

        def call
          existing = repository.find(pizza_id)
          if existing
            Order.new(id: existing.id, pizza_id: pizza_id, quantity: quantity)
          else
            Order.new(pizza_id: pizza_id, quantity: quantity)
          end
        end
      end
    end
  end
end

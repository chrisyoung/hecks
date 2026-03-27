module PizzasDomain
  class Order
    module Commands
      class CancelOrder
        include PizzasDomain::Runtime::Command
        emits "CanceledOrder"

        attr_reader :order_id

        def initialize(order_id: nil)
          @order_id = order_id
        end

        def call
          existing = repository.find(order_id)
          if existing
            Order.new(
              id: existing.id,
              customer_name: existing.customer_name,
              items: existing.items,
              status: "cancelled"
            )
          else
            raise PizzasDomain::Error, "Order not found: #{order_id}"
          end
        end
      end
    end
  end
end

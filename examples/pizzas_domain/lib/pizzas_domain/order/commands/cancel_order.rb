module PizzasDomain
  class Order
    module Commands
      class CancelOrder
        include Hecks::Command
        emits "CanceledOrder"

        attr_reader :order

        def initialize(order: nil)
          @order = order
        end

        def call
          existing = repository.find(order)
          if existing
            Order.new(
              id: existing.id,
              customer_name: existing.customer_name,
              items: existing.items,
              status: "cancelled"
            )
          else
            raise PizzasDomain::Error, "Order not found: #{order}"
          end
        end
      end
    end
  end
end

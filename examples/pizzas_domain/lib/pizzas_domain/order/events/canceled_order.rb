module PizzasDomain
  class Order
    module Events
      class CanceledOrder
        attr_reader :aggregate_id, :order, :customer_name, :items, :status, :occurred_at

        def initialize(aggregate_id: nil, order: nil, customer_name: nil, items: nil, status: nil)
          @aggregate_id = aggregate_id
          @order = order
          @customer_name = customer_name
          @items = items
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

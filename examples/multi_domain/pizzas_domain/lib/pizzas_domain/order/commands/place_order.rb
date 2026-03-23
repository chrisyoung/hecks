require 'hecks/command'

module PizzasDomain
  class Order
    module Commands
      class PlaceOrder
        include Hecks::Command

        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
        end

        def call
          run_handler
          existing = repository.find(pizza_id)
          if existing
            save Order.new(id: existing.id, pizza_id: pizza_id, quantity: quantity, created_at: existing.created_at, updated_at: Time.now)
          else
            save Order.new(pizza_id: pizza_id, quantity: quantity, created_at: Time.now, updated_at: Time.now)
          end
          emit Events::PlacedOrder.new(pizza_id: pizza_id, quantity: quantity)
          record_event(aggregate.id, event)
          self
        end
      end
    end
  end
end

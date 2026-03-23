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
          freeze
        end

        def call
          run_handler
          existing = repository.find(pizza_id)
          if existing
            aggregate = Order.new(id: existing.id, pizza_id: pizza_id, quantity: quantity, created_at: existing.created_at, updated_at: Time.now)
          else
            aggregate = Order.new(pizza_id: pizza_id, quantity: quantity, created_at: Time.now, updated_at: Time.now)
          end
          repository.save(aggregate)
          event = emit Events::PlacedOrder.new(pizza_id: pizza_id, quantity: quantity)
          record_event(aggregate.id, event)
          aggregate
        end
      end
    end
  end
end

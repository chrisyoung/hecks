require 'hecks/command'

module ShippingDomain
  class Shipment
    module Commands
      class CreateShipment
        include Hecks::Command

        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
          freeze
        end

        def call
          run_handler
          aggregate = Shipment.new(pizza_id: pizza_id, quantity: quantity, created_at: Time.now, updated_at: Time.now)
          repository.save(aggregate)
          event = emit Events::CreatedShipment.new(pizza_id: pizza_id, quantity: quantity)
          record_event(aggregate.id, event)
          aggregate
        end
      end
    end
  end
end

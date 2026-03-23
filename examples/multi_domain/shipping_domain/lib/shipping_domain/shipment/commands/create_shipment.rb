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
        end

        def call
          run_handler
          save Shipment.new(pizza_id: pizza_id, quantity: quantity, created_at: Time.now, updated_at: Time.now)
          emit Events::CreatedShipment.new(pizza_id: pizza_id, quantity: quantity)
          record_event(aggregate.id, event)
          self
        end
      end
    end
  end
end

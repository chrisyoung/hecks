require 'hecks/command'

module ShippingDomain
  class Shipment
    module Commands
      class CreateShipment
        include Hecks::Command
        emits "CreatedShipment"

        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
        end

        def call
          save Shipment.new(pizza_id: pizza_id, quantity: quantity, created_at: Time.now, updated_at: Time.now)
        end
      end
    end
  end
end

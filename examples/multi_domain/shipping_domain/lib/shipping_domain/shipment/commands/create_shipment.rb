module ShippingDomain
  class Shipment
    module Commands
      class CreateShipment
        emits "CreatedShipment"

        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
        end

        def call
          Shipment.new(pizza_id: pizza_id, quantity: quantity)
        end
      end
    end
  end
end

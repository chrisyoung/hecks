module ShippingDomain
  class Shipment
    module Commands
      class ShipShipment
        include Hecks::Command
        emits "ShippedShipment"

        attr_reader :shipment_id

        def initialize(shipment_id: nil)
          @shipment_id = shipment_id
        end

        def call
          existing = repository.find(shipment_id)
          if existing
            Shipment.new(id: existing.id, pizza_id: existing.pizza_id, quantity: existing.quantity, status: existing.status)
          else
            Shipment.new()
          end
        end
      end
    end
  end
end

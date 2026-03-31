module ShippingDomain
  class Shipment
    module Commands
      class ShipShipment
        include Hecks::Command
        emits "ShippedShipment"

        attr_reader :shipment

        def initialize(shipment: nil)
          @shipment = shipment
        end

        def call
          existing = repository.find(shipment)
          if existing
            Shipment.new(id: existing.id, pizza: existing.pizza, quantity: existing.quantity, status: existing.status)
          else
            Shipment.new()
          end
        end
      end
    end
  end
end

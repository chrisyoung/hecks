module ShippingDomain
  class Shipment
    module Commands
      class ShipShipment
        attr_reader :shipment_id

        def initialize(shipment_id: nil)
          @shipment_id = shipment_id
          freeze
        end
      end
    end
  end
end

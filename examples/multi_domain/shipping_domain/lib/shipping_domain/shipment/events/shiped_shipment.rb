module ShippingDomain
  class Shipment
    module Events
      class ShipedShipment
        attr_reader :shipment_id, :occurred_at

        def initialize(shipment_id: nil)
          @shipment_id = shipment_id
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

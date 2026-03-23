module ShippingDomain
  class Shipment
    module Policies
      class ShipOnOrder
        EVENT   = "PlacedOrder"
        TRIGGER = "CreateShipment"

        def self.event   = EVENT
        def self.trigger = TRIGGER
      end
    end
  end
end

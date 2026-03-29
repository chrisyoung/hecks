module ShippingDomain
  class Shipment
    module Policies
      class ShipOnOrder
        EVENT   = "PlacedOrder"
        TRIGGER = "CreateShipment"
        ASYNC   = false

        def self.event   = EVENT
        def self.trigger = TRIGGER
        def self.async   = ASYNC

        attr_reader :result

        def call(event)
          # Maps event attrs and dispatches trigger command
          self
        end
      end
    end
  end
end

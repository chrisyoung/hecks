module ShippingDomain
  class Shipment
    module Queries
      class ReadyToShip
        def call
          where(status: "pending")
        end
      end
    end
  end
end

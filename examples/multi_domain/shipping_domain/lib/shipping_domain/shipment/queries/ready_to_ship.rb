require 'hecks/query'

module ShippingDomain
  class Shipment
    module Queries
      class ReadyToShip
        include Hecks::Query

        def call
          where(status: "pending")
        end
      end
    end
  end
end

require 'hecks/command'

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
            save Shipment.new(id: existing.id, pizza_id: existing.pizza_id, quantity: existing.quantity, status: existing.status, created_at: existing.created_at, updated_at: Time.now)
          else
            save Shipment.new(created_at: Time.now, updated_at: Time.now)
          end
        end
      end
    end
  end
end

require 'hecks/command'

module ShippingDomain
  class Shipment
    module Commands
      class ShipShipment
        include Hecks::Command

        attr_reader :shipment_id

        def initialize(shipment_id: nil)
          @shipment_id = shipment_id
          freeze
        end

        def call
          run_handler
          existing = repository.find(shipment_id)
          if existing
            aggregate = Shipment.new(id: existing.id, pizza_id: existing.pizza_id, quantity: existing.quantity, status: existing.status, created_at: existing.created_at, updated_at: Time.now)
          else
            aggregate = Shipment.new(created_at: Time.now, updated_at: Time.now)
          end
          repository.save(aggregate)
          event = emit Events::ShippedShipment.new(shipment_id: shipment_id)
          record_event(aggregate.id, event)
          aggregate
        end
      end
    end
  end
end

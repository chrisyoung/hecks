module ShippingDomain
  class Shipment
    module Events
      class ShippedShipment
        attr_reader :aggregate_id, :shipment, :pizza, :quantity, :status, :occurred_at

        def initialize(aggregate_id: nil, shipment: nil, pizza: nil, quantity: nil, status: nil)
          @aggregate_id = aggregate_id
          @shipment = shipment
          @pizza = pizza
          @quantity = quantity
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

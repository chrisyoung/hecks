module ShippingDomain
  class Shipment
    module Events
      class CreatedShipment
        attr_reader :aggregate_id, :pizza_id, :quantity, :status, :occurred_at

        def initialize(aggregate_id: nil, pizza_id: nil, quantity: nil, status: nil)
          @aggregate_id = aggregate_id
          @pizza_id = pizza_id
          @quantity = quantity
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

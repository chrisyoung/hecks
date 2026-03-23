module ShippingDomain
  class Shipment
    module Events
      class CreatedShipment
        attr_reader :pizza_id, :quantity, :occurred_at

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

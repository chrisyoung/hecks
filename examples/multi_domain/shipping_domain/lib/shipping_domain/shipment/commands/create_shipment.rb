module ShippingDomain
  class Shipment
    module Commands
      class CreateShipment
        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
          freeze
        end
      end
    end
  end
end

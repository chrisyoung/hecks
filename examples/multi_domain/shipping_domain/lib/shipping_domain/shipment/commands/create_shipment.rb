module ShippingDomain
  class Shipment
    module Commands
      class CreateShipment
        include Hecks::Command
        emits "CreatedShipment"

        attr_reader :pizza, :quantity

        def initialize(pizza: nil, quantity: nil)
          @pizza = pizza
          @quantity = quantity
        end

        def call
          Shipment.new(pizza: pizza, quantity: quantity)
        end
      end
    end
  end
end

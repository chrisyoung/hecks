module ShippingDomain
  class Shipment

    module Commands
      autoload :CreateShipment, "shipping_domain/shipment/commands/create_shipment"
      autoload :ShipShipment, "shipping_domain/shipment/commands/ship_shipment"
    end

    module Events
      autoload :CreatedShipment, "shipping_domain/shipment/events/created_shipment"
      autoload :ShipedShipment, "shipping_domain/shipment/events/shiped_shipment"
    end

    module Policies
      autoload :ShipOnOrder, "shipping_domain/shipment/policies/ship_on_order"
    end

    module Queries
      autoload :ReadyToShip, "shipping_domain/shipment/queries/ready_to_ship"
    end

    attr_reader :id, :pizza_id, :quantity, :status, :created_at, :updated_at

    def initialize(pizza_id: nil, quantity: nil, status: nil, id: nil, created_at: nil, updated_at: nil)
      @id = id || generate_id
      @pizza_id = pizza_id
      @quantity = quantity
      @status = status
      @created_at = created_at || Time.now
      @updated_at = updated_at || Time.now
      validate!
      check_invariants!
    end

    def ==(other)
      other.is_a?(self.class) && id == other.id
    end
    alias eql? ==

    def hash
      [self.class, id].hash
    end

    private

    def generate_id
      SecureRandom.uuid
    end

    def validate!; end

    def check_invariants!; end
  end
end

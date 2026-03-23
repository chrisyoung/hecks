module ShippingDomain
  module Ports
    module ShipmentRepository
      def find(id)
        raise NotImplementedError, "#{self.class}#find not implemented"
      end

      def save(shipment)
        raise NotImplementedError, "#{self.class}#save not implemented"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end

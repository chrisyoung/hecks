module PizzasDomain
  module Ports
    module OrderRepository
      def find(id)
        raise NotImplementedError, "#{self.class}#find not implemented"
      end

      def save(order)
        raise NotImplementedError, "#{self.class}#save not implemented"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end

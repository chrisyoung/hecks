module PizzasDomain
  module Ports
    module PizzaRepository
      def find(id)
        raise NotImplementedError, "#{self.class}#find not implemented"
      end

      def save(pizza)
        raise NotImplementedError, "#{self.class}#save not implemented"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end

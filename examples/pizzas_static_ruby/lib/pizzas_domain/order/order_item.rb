module PizzasDomain
  class Order
    class OrderItem
      attr_reader :pizza, :quantity

      def initialize(pizza:, quantity:)
        @pizza = pizza
        @quantity = quantity
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          pizza == other.pizza &&
          quantity == other.quantity
      end
      alias eql? ==

      def hash
        [self.class, pizza, quantity].hash
      end

      private

      def check_invariants!
        raise InvariantError, "quantity must be positive" unless instance_eval(&proc { quantity > 0 })
      end
    end
  end
end

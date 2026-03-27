module PizzasDomain
  class Order
    class OrderItem
      attr_reader :pizza_id, :quantity

      def initialize(pizza_id:, quantity:)
        @pizza_id = pizza_id
        @quantity = quantity
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          pizza_id == other.pizza_id &&
          quantity == other.quantity
      end
      alias eql? ==

      def hash
        [self.class, pizza_id, quantity].hash
      end

      private

      def check_invariants!
        raise InvariantError, "quantity must be positive" unless instance_eval(&proc { true })
      end
    end
  end
end

module PizzasDomain
  class Pizza
    class Topping
      attr_reader :name, :amount

      def initialize(name:, amount:)
        @name = name
        @amount = amount
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          name == other.name &&
          amount == other.amount
      end
      alias eql? ==

      def hash
        [self.class, name, amount].hash
      end

      private

      def check_invariants!
        raise InvariantError, "amount must be positive" unless instance_eval(&proc { true })
      end
    end
  end
end

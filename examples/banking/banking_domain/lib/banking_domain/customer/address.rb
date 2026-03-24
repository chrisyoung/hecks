module BankingDomain
  class Customer
    class Address
      attr_reader :street, :city, :state, :zip

      def initialize(street:, city:, state:, zip:)
        @street = street
        @city = city
        @state = state
        @zip = zip
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          street == other.street &&
          city == other.city &&
          state == other.state &&
          zip == other.zip
      end
      alias eql? ==

      def hash
        [self.class, street, city, state, zip].hash
      end

      private

      def check_invariants!; end
    end
  end
end

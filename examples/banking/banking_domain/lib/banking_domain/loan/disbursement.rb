module BankingDomain
  class Loan
    class Disbursement
      attr_reader :amount, :disbursed_at, :method

      def initialize(amount:, disbursed_at:, method:)
        @amount = amount
        @disbursed_at = disbursed_at
        @method = method
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          amount == other.amount &&
          disbursed_at == other.disbursed_at &&
          method == other.method
      end
      alias eql? ==

      def hash
        [self.class, amount, disbursed_at, method].hash
      end

      private

      def check_invariants!; end
    end
  end
end

module BankingDomain
  class Loan
    class PaymentScheduleEntry
      attr_reader :due_date, :principal_amount, :interest_amount, :total_amount

      def initialize(due_date:, principal_amount:, interest_amount:, total_amount:)
        @due_date = due_date
        @principal_amount = principal_amount
        @interest_amount = interest_amount
        @total_amount = total_amount
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          due_date == other.due_date &&
          principal_amount == other.principal_amount &&
          interest_amount == other.interest_amount &&
          total_amount == other.total_amount
      end
      alias eql? ==

      def hash
        [self.class, due_date, principal_amount, interest_amount, total_amount].hash
      end

      private

      def check_invariants!; end
    end
  end
end

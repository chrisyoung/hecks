module BankingDomain
  class Loan
    module Events
      class MadePayment
        attr_reader :loan_id, :amount, :occurred_at

        def initialize(loan_id: nil, amount: nil)
          @loan_id = loan_id
          @amount = amount
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

module BankingDomain
  class Loan
    module Events
      class DefaultedLoan
        attr_reader :loan_id, :customer_id, :occurred_at

        def initialize(loan_id: nil, customer_id: nil)
          @loan_id = loan_id
          @customer_id = customer_id
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

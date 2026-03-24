module BankingDomain
  class Loan
    module Events
      class IssuedLoan
        attr_reader :customer_id, :account_id, :principal, :rate, :term_months, :occurred_at

        def initialize(customer_id: nil, account_id: nil, principal: nil, rate: nil, term_months: nil)
          @customer_id = customer_id
          @account_id = account_id
          @principal = principal
          @rate = rate
          @term_months = term_months
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

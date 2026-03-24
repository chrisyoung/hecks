module BankingDomain
  class Loan
    module Events
      class RefinancedLoan
        attr_reader :loan_id, :new_rate, :new_term_months, :occurred_at

        def initialize(loan_id: nil, new_rate: nil, new_term_months: nil)
          @loan_id = loan_id
          @new_rate = new_rate
          @new_term_months = new_term_months
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

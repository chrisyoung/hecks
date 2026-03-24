module BankingDomain
  class Loan
    module Commands
      class RefinanceLoan
        emits "RefinancedLoan"

        attr_reader :loan_id
        attr_reader :new_rate
        attr_reader :new_term_months

        def initialize(
          loan_id: nil,
          new_rate: nil,
          new_term_months: nil
        )
          @loan_id = loan_id
          @new_rate = new_rate
          @new_term_months = new_term_months
        end

        def call
          existing = repository.find(loan_id)
          if existing
            Loan.new(
              id: existing.id,
              customer_id: existing.customer_id,
              account_id: existing.account_id,
              principal: existing.principal,
              rate: existing.rate,
              term_months: existing.term_months,
              status: existing.status,
              remaining_balance: existing.remaining_balance,
              payment_schedule: existing.payment_schedule
            )
          else
            Loan.new()
          end
        end
      end
    end
  end
end

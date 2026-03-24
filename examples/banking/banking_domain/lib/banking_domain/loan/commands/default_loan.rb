module BankingDomain
  class Loan
    module Commands
      class DefaultLoan
        emits "DefaultedLoan"

        attr_reader :loan_id, :customer_id

        def initialize(loan_id: nil, customer_id: nil)
          @loan_id = loan_id
          @customer_id = customer_id
        end

        def call
          existing = repository.find(loan_id)
          raise "Loan not found" unless existing
          Loan.new(id: existing.id, customer_id: existing.customer_id, account_id: existing.account_id, principal: existing.principal, rate: existing.rate, term_months: existing.term_months, remaining_balance: existing.remaining_balance, status: "defaulted")
        end
      end
    end
  end
end

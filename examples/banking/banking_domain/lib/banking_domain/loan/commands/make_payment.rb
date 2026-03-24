module BankingDomain
  class Loan
    module Commands
      class MakePayment
        emits "MadePayment"

        attr_reader :loan_id, :amount

        def initialize(loan_id: nil, amount: nil)
          @loan_id = loan_id
          @amount = amount
        end

        def call
          existing = repository.find(loan_id)
          raise "Loan not found" unless existing
          raise "Loan is #{existing.status}" unless existing.status == "active"
          new_balance = existing.remaining_balance - amount
          new_status = new_balance <= 0 ? "paid_off" : "active"
          Loan.new(id: existing.id, customer_id: existing.customer_id, account_id: existing.account_id, principal: existing.principal, rate: existing.rate, term_months: existing.term_months, remaining_balance: [new_balance, 0.0].max, status: new_status)
        end
      end
    end
  end
end

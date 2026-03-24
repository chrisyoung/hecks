module BankingDomain
  class Loan
    module Commands
      class IssueLoan
        emits "IssuedLoan"

        attr_reader :customer_id
        attr_reader :account_id
        attr_reader :principal
        attr_reader :rate
        attr_reader :term_months

        def initialize(
          customer_id: nil,
          account_id: nil,
          principal: nil,
          rate: nil,
          term_months: nil
        )
          @customer_id = customer_id
          @account_id = account_id
          @principal = principal
          @rate = rate
          @term_months = term_months
        end

        def call
          Loan.new(customer_id: customer_id, account_id: account_id, principal: principal, rate: rate, term_months: term_months, remaining_balance: principal, status: "active")
        end
      end
    end
  end
end

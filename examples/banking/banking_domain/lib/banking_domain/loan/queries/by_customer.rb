module BankingDomain
  class Loan
    module Queries
      class ByCustomer
        def call
          where(customer_id: customer_id)
        end
      end
    end
  end
end

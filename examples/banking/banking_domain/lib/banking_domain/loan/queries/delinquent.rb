module BankingDomain
  class Loan
    module Queries
      class Delinquent
        def call
          where(status: "defaulted")
        end
      end
    end
  end
end

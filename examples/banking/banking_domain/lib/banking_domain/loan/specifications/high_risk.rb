module BankingDomain
  class Loan
    module Specifications
      class HighRisk
        def satisfied_by?(loan)
          loan.principal > 50_000 && loan.rate > 10
        end
      end
    end
  end
end

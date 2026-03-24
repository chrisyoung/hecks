module BankingDomain
  class Loan
    module Policies
      class DisburseFunds
        def self.event   = "IssuedLoan"
        def self.trigger = "Deposit"
        def self.async   = false
      end
    end
  end
end

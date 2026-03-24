module BankingDomain
  class Loan
    module Policies
      class SuspendOnDefault
        def self.event   = "DefaultedLoan"
        def self.trigger = "SuspendCustomer"
        def self.async   = false
      end
    end
  end
end

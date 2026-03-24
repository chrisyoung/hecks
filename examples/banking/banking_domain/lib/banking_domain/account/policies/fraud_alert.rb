module BankingDomain
  class Account
    module Policies
      class FraudAlert
        def self.event   = "Withdrew"
        def self.trigger = "FlagSuspiciousActivity"
        def self.async   = false
      end
    end
  end
end

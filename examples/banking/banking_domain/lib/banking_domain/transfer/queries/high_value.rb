module BankingDomain
  class Transfer
    module Queries
      class HighValue
        def call
          where(amount: Hecks::Querying::Operators::Gte.new(1000.0))
        end
      end
    end
  end
end

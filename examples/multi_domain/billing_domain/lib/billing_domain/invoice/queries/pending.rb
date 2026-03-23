module BillingDomain
  class Invoice
    module Queries
      class Pending
        def call
          true
        end
      end
    end
  end
end

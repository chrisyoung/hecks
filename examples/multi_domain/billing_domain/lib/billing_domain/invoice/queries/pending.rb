require 'hecks/query'

module BillingDomain
  class Invoice
    module Queries
      class Pending
        include Hecks::Query

        def call
          where(status: "pending")
        end
      end
    end
  end
end

require 'hecks/query'

module BillingDomain
  class Invoice
    module Queries
      class Pending
        include Hecks::Query

        def call
          true
        end
      end
    end
  end
end

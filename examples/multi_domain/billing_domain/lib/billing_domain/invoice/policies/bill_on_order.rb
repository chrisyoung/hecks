module BillingDomain
  class Invoice
    module Policies
      class BillOnOrder
        EVENT   = "PlacedOrder"
        TRIGGER = "CreateInvoice"

        def self.event   = EVENT
        def self.trigger = TRIGGER
      end
    end
  end
end

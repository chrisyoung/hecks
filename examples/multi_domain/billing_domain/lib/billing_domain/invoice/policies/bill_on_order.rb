module BillingDomain
  class Invoice
    module Policies
      class BillOnOrder
        remove_const(:EVENT) if const_defined?(:EVENT)
        EVENT   = "PlacedOrder"
        remove_const(:TRIGGER) if const_defined?(:TRIGGER)
        TRIGGER = "CreateInvoice"
        remove_const(:ASYNC) if const_defined?(:ASYNC)
        ASYNC   = false

        def self.event   = EVENT
        def self.trigger = TRIGGER
        def self.async   = ASYNC
      end
    end
  end
end

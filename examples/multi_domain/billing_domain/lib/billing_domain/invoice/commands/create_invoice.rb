require 'hecks/command'

module BillingDomain
  class Invoice
    module Commands
      class CreateInvoice
        include Hecks::Command

        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
        end

        def call
          run_handler
          save Invoice.new(pizza_id: pizza_id, quantity: quantity, created_at: Time.now, updated_at: Time.now)
          emit Events::CreatedInvoice.new(pizza_id: pizza_id, quantity: quantity)
          record_event(aggregate.id, event)
          self
        end
      end
    end
  end
end

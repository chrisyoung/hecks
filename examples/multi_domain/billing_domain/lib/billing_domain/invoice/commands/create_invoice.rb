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
          freeze
        end

        def call
          run_handler
          aggregate = Invoice.new(pizza_id: pizza_id, quantity: quantity, created_at: Time.now, updated_at: Time.now)
          repository.save(aggregate)
          event = emit Events::CreatedInvoice.new(pizza_id: pizza_id, quantity: quantity)
          record_event(aggregate.id, event)
          aggregate
        end
      end
    end
  end
end

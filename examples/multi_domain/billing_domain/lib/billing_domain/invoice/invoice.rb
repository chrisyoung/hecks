require 'hecks/mixins/model'

module BillingDomain
  class Invoice
    include Hecks::Model

    attribute :pizza_id
    attribute :quantity
    attribute :status
  end
end

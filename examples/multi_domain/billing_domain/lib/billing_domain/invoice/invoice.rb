require 'hecks/mixins/model'

module BillingDomain
  class Invoice
    include Hecks::Model

    attribute :pizza
    attribute :quantity
    attribute :status
  end
end

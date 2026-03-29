require 'hecks/mixins/model'

module ShippingDomain
  class Shipment
    include Hecks::Model

    attribute :pizza_id
    attribute :quantity
    attribute :status
  end
end

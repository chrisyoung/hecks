require 'hecks/model'

module ShippingDomain
  class Shipment
    include Hecks::Model

    attr_reader :pizza_id, :quantity, :status

    def initialize(pizza_id: nil, quantity: nil, status: nil, id: nil)
      @id = id || generate_id
      @pizza_id = pizza_id
      @quantity = quantity
      @status = status
      validate!
      check_invariants!
    end
  end
end

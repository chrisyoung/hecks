require 'hecks/model'

module PizzasDomain
  class Order
    include Hecks::Model

    attr_reader :pizza_id, :quantity

    def initialize(pizza_id: nil, quantity: nil, id: nil)
      @id = id || generate_id
      @pizza_id = pizza_id
      @quantity = quantity
      validate!
      check_invariants!
    end
  end
end

require 'hecks/model'

module PizzasDomain
  class Pizza
    include Hecks::Model

    attr_reader :name, :style, :price

    def initialize(name: nil, style: nil, price: nil, id: nil)
      @id = id || generate_id
      @name = name
      @style = style
      @price = price
      validate!
      check_invariants!
    end
  end
end

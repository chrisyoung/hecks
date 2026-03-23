module PizzasDomain
  class Pizza
    module Commands
      class CreatePizza
        attr_reader :name, :style, :price

        def initialize(name: nil, style: nil, price: nil)
          @name = name
          @style = style
          @price = price
          freeze
        end
      end
    end
  end
end

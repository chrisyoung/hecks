module PizzasDomain
  class Pizza
    module Commands
      class CreatePizza
        emits "CreatedPizza"

        attr_reader :name, :style, :price

        def initialize(name: nil, style: nil, price: nil)
          @name = name
          @style = style
          @price = price
        end

        def call
          Pizza.new(name: name, style: style, price: price)
        end
      end
    end
  end
end

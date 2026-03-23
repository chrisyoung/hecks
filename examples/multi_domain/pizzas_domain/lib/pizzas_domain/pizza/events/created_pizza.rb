module PizzasDomain
  class Pizza
    module Events
      class CreatedPizza
        attr_reader :name, :style, :price, :occurred_at

        def initialize(name: nil, style: nil, price: nil)
          @name = name
          @style = style
          @price = price
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end

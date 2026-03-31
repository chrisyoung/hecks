module PizzasDomain
  class Pizza
    module Events
      class CreatedPizza
        attr_reader :aggregate_id, :name, :style, :price, :occurred_at

        def initialize(aggregate_id: nil, name: nil, style: nil, price: nil)
          @aggregate_id = aggregate_id
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

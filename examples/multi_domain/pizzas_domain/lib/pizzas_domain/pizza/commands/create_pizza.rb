require 'hecks/command'

module PizzasDomain
  class Pizza
    module Commands
      class CreatePizza
        include Hecks::Command
        emits "CreatedPizza"

        attr_reader :name, :style, :price

        def initialize(name: nil, style: nil, price: nil)
          @name = name
          @style = style
          @price = price
        end

        def call
          save Pizza.new(name: name, style: style, price: price, created_at: Time.now, updated_at: Time.now)
        end
      end
    end
  end
end

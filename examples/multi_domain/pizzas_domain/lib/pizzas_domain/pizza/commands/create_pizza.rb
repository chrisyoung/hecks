require 'hecks/command'

module PizzasDomain
  class Pizza
    module Commands
      class CreatePizza
        include Hecks::Command

        attr_reader :name, :style, :price

        def initialize(name: nil, style: nil, price: nil)
          @name = name
          @style = style
          @price = price
        end

        def call
          run_handler
          save Pizza.new(name: name, style: style, price: price, created_at: Time.now, updated_at: Time.now)
          emit Events::CreatedPizza.new(name: name, style: style, price: price)
          record_event(aggregate.id, event)
          self
        end
      end
    end
  end
end

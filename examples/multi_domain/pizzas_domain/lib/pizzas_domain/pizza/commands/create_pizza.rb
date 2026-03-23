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
          freeze
        end

        def call
          run_handler
          aggregate = Pizza.new(name: name, style: style, price: price, created_at: Time.now, updated_at: Time.now)
          repository.save(aggregate)
          event = emit Events::CreatedPizza.new(name: name, style: style, price: price)
          record_event(aggregate.id, event)
          aggregate
        end
      end
    end
  end
end

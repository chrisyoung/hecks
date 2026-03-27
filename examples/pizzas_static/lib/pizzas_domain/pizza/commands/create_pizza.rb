module PizzasDomain
  class Pizza
    module Commands
      class CreatePizza
        include PizzasDomain::Runtime::Command
        emits "CreatedPizza"

        attr_reader :name, :description

        def initialize(name: nil, description: nil)
          @name = name
          @description = description
        end

        def call
          Pizza.new(name: name, description: description)
        end
      end
    end
  end
end

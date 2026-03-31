module PizzasDomain
  class Pizza
    module Commands
      class AddTopping
        include Hecks::Command
        emits "AddedTopping"

        attr_reader :pizza
        attr_reader :name
        attr_reader :amount

        def initialize(
          pizza: nil,
          name: nil,
          amount: nil
        )
          @pizza = pizza
          @name = name
          @amount = amount
        end

        def call
          existing = repository.find(pizza)
          if existing
            Pizza.new(
              id: existing.id,
              name: name,
              description: existing.description,
              toppings: existing.toppings + [Topping.new(name: name, amount: amount)]
            )
          else
            raise PizzasDomain::Error, "Pizza not found: #{pizza}"
          end
        end
      end
    end
  end
end

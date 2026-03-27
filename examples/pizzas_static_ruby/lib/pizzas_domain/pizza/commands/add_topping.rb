module PizzasDomain
  class Pizza
    module Commands
      class AddTopping
        include PizzasDomain::Runtime::Command
        emits "AddedTopping"

        attr_reader :pizza_id
        attr_reader :name
        attr_reader :amount

        def initialize(
          pizza_id: nil,
          name: nil,
          amount: nil
        )
          @pizza_id = pizza_id
          @name = name
          @amount = amount
        end

        def call
          existing = repository.find(pizza_id)
          if existing
            Pizza.new(
              id: existing.id,
              name: name,
              description: existing.description,
              toppings: existing.toppings + [Topping.new(name: name, amount: amount)]
            )
          else
            raise Hecks::Error, "Pizza not found: #{pizza_id}"
          end
        end
      end
    end
  end
end

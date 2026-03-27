module PizzasDomain
  class Order
    module Queries
      class Pending
        def call
          true
        end
      end
    end
  end
end

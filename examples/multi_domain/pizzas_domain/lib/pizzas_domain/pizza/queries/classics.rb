module PizzasDomain
  class Pizza
    module Queries
      class Classics
        def call
          where(style: "Classic")
        end
      end
    end
  end
end

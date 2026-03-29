module PizzasDomain
  class Pizza
    module Queries
      class ByDescription
        def call(desc)
          where(description: desc)
        end
      end
    end
  end
end

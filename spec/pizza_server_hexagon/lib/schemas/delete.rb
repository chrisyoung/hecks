module PizzaServerHexagon
  module Schemas
    module Pizzas
      Delete = Dry::Validation.Schema do
        required(:id).filled(:int?)
      end
    end
  end
end
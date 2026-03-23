require 'hecks/model'

module PizzasDomain
  class Order
    include Hecks::Model

    attribute :pizza_id
    attribute :quantity
  end
end

require 'hecks/mixins/model'

module PizzasDomain
  class Order
    include Hecks::Model

    attribute :quantity
    attribute :pizza
  end
end

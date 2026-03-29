require 'hecks/mixins/model'

module PizzasDomain
  class Pizza
    include Hecks::Model

    attribute :name
    attribute :style
    attribute :price
  end
end

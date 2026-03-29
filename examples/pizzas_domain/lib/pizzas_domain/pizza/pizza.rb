require 'hecks/mixins/model'

module PizzasDomain
  class Pizza
    autoload :Topping, "pizzas_domain/pizza/topping"

    include Hecks::Model

    attribute :name
    attribute :description
    attribute :toppings, default: [], freeze: true

    private

    def validate!
      raise ValidationError.new("name can't be blank", field: :name, rule: :presence) if name.nil? || (name.respond_to?(:empty?) && name.empty?)
      raise ValidationError.new("description can't be blank", field: :description, rule: :presence) if description.nil? || (description.respond_to?(:empty?) && description.empty?)
    end
  end
end

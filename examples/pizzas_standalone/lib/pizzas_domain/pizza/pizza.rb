module PizzasDomain
  class Pizza
    autoload :Topping, "pizzas_domain/pizza/topping"
    include PizzasDomain::Runtime::Model

    class << self
      attr_accessor :repository, :event_bus, :command_bus
    end

    attribute :name
    attribute :description
    attribute :toppings, default: [], freeze: true

    private

    def validate!
      raise ValidationError.new("name can't be blank", field: :name, rule: :presence) if name.nil? || (name.respond_to?(:empty?) && name.empty?)
    end
  end
end

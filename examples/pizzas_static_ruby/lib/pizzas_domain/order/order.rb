module PizzasDomain
  class Order
    autoload :OrderItem, "pizzas_domain/order/order_item"
    include PizzasDomain::Runtime::Model

    class << self
      attr_accessor :repository, :event_bus, :command_bus
    end

    attribute :customer_name
    attribute :items, default: [], freeze: true
    attribute :status, default: "pending"

    # State predicates — see lifecycle.rb for full state machine
    def pending?; status == "pending"; end
    def cancelled?; status == "cancelled"; end

    private

    def validate!
      raise ValidationError.new("customer_name can't be blank", field: :customer_name, rule: :presence) if customer_name.nil? || (customer_name.respond_to?(:empty?) && customer_name.empty?)
    end
  end
end

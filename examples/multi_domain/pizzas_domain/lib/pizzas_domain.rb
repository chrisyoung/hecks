require "securerandom"

module PizzasDomain
  class ValidationError < StandardError; end
  class InvariantError < StandardError; end

  autoload :Pizza, "pizzas_domain/pizza/pizza"
  autoload :Order, "pizzas_domain/order/order"

  module Ports
    autoload :PizzaRepository, "pizzas_domain/ports/pizza_repository"
    autoload :OrderRepository, "pizzas_domain/ports/order_repository"
  end

  module Adapters
    autoload :PizzaMemoryRepository, "pizzas_domain/adapters/pizza_memory_repository"
    autoload :OrderMemoryRepository, "pizzas_domain/adapters/order_memory_repository"
  end
end

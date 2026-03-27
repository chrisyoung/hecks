require "securerandom"
require_relative "pizzas_domain/runtime/errors"

module PizzasDomain
  module Runtime
    autoload :Operators, "pizzas_domain/runtime/operators"
    autoload :EventBus, "pizzas_domain/runtime/event_bus"
    autoload :CommandBus, "pizzas_domain/runtime/command_bus"
    autoload :QueryBuilder, "pizzas_domain/runtime/query_builder"
    autoload :Model, "pizzas_domain/runtime/model"
    autoload :Command, "pizzas_domain/runtime/command"
    autoload :Query, "pizzas_domain/runtime/query"
    autoload :Specification, "pizzas_domain/runtime/specification"
  end

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

  ROLES = ["admin", "customer"].freeze
  PORTS = {"admin"=>{"Pizza"=>["find", "all", "create_pizza", "add_topping"], "Order"=>["find", "all", "place_order", "cancel_order"]}, "customer"=>{"Pizza"=>["find", "all"], "Order"=>["find", "all", "place_order"]}}.freeze
  VALIDATIONS = {"Pizza/create_pizza"=>{"name"=>{"presence"=>true}, "description"=>{"presence"=>true}}, "Pizza/add_topping"=>{"name"=>{"presence"=>true}, "amount"=>{"presence"=>true, "positive"=>true}}, "Order/place_order"=>{"customer_name"=>{"presence"=>true}, "pizza_id"=>{"presence"=>true}, "quantity"=>{"presence"=>true, "positive"=>true}}}.freeze
end

require_relative "../boot"
PizzasDomain.boot unless ENV["DOMAIN_SKIP_BOOT"]

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

  class << self
    attr_accessor :event_bus, :command_bus, :current_role
    attr_reader :config

    def role_allows?(aggregate, action)
      return true unless current_role
      allowed = PORTS.dig(current_role.to_s, aggregate.to_s)
      return true unless allowed
      allowed.include?(action.to_s)
    end

    def boot(adapter: :memory)
      @current_role ||= "admin"
      @config = { adapter: adapter, booted_at: Time.now }
      @event_bus = Runtime::EventBus.new
      @command_bus = Runtime::CommandBus.new(event_bus: @event_bus)

      Pizza.repository = Adapters::PizzaMemoryRepository.new
      Pizza.event_bus = @event_bus
      Pizza.command_bus = @command_bus
      Order.repository = Adapters::OrderMemoryRepository.new
      Order.event_bus = @event_bus
      Order.command_bus = @command_bus

      Pizza::Commands::CreatePizza.repository = Pizza.repository
      Pizza::Commands::CreatePizza.event_bus = @event_bus
      Pizza::Commands::CreatePizza.command_bus = @command_bus
      Pizza::Commands::CreatePizza.aggregate_type = "Pizza"
      Pizza.define_singleton_method(:create_pizza) { |**attrs| Pizza::Commands::CreatePizza.call(**attrs) }
      Pizza::Commands::AddTopping.repository = Pizza.repository
      Pizza::Commands::AddTopping.event_bus = @event_bus
      Pizza::Commands::AddTopping.command_bus = @command_bus
      Pizza::Commands::AddTopping.aggregate_type = "Pizza"
      Pizza.define_singleton_method(:add_topping) { |**attrs| Pizza::Commands::AddTopping.call(**attrs) }
      Order::Commands::PlaceOrder.repository = Order.repository
      Order::Commands::PlaceOrder.event_bus = @event_bus
      Order::Commands::PlaceOrder.command_bus = @command_bus
      Order::Commands::PlaceOrder.aggregate_type = "Order"
      Order.define_singleton_method(:place_order) { |**attrs| Order::Commands::PlaceOrder.call(**attrs) }
      Order::Commands::CancelOrder.repository = Order.repository
      Order::Commands::CancelOrder.event_bus = @event_bus
      Order::Commands::CancelOrder.command_bus = @command_bus
      Order::Commands::CancelOrder.aggregate_type = "Order"
      Order.define_singleton_method(:cancel_order) { |**attrs| Order::Commands::CancelOrder.call(**attrs) }
      Pizza::Queries::ByDescription.repository = Pizza.repository
      Pizza.define_singleton_method(:by_description) { |*args| Pizza::Queries::ByDescription.call(*args) }
      Order::Queries::Pending.repository = Order.repository
      Order.define_singleton_method(:pending) { |*args| Order::Queries::Pending.call(*args) }
      Pizza.define_singleton_method(:find) { |id| repository.find(id) }
      Pizza.define_singleton_method(:all) { repository.all }
      Pizza.define_singleton_method(:count) { repository.count }
      Pizza.define_singleton_method(:where) { |**conds| Runtime::QueryBuilder.new(repository).where(**conds) }
      Order.define_singleton_method(:find) { |id| repository.find(id) }
      Order.define_singleton_method(:all) { repository.all }
      Order.define_singleton_method(:count) { repository.count }
      Order.define_singleton_method(:where) { |**conds| Runtime::QueryBuilder.new(repository).where(**conds) }

      Object.const_set(:Pizza, Pizza) unless Object.const_defined?(:Pizza)
      Object.const_set(:Order, Order) unless Object.const_defined?(:Order)
      self
    end

    def reboot(adapter: :memory)
      boot(adapter: adapter)
    end

    def on(event_name, &block)
      @event_bus.subscribe(event_name, &block)
    end

    def events
      @event_bus.events
    end

    def serve(port: 9292)
      require_relative "pizzas_domain/server/domain_app"
      Server::DomainApp.new(self).start(port: port)
    end

    def domain_info
      {
        "Pizza" => { commands: ["CreatePizza", "AddTopping"], ports: { :admin => ["find", "all", "create_pizza", "add_topping"], :customer => ["find", "all"] }, count: Pizza.count },
        "Order" => { commands: ["PlaceOrder", "CancelOrder"], ports: { :admin => ["find", "all", "place_order", "cancel_order"], :customer => ["find", "all", "place_order"] }, count: Order.count }
      }
    end

    def policy_info
      []
    end
  end
end

# Auto-boot with memory adapters on require
PizzasDomain.boot unless ENV["HECKS_SKIP_BOOT"]

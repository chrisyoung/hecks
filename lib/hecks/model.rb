# Hecks::Model
#
# Mixin for generated aggregate classes. Provides identity, id generation,
# validation hooks, auto-discovery of Commands/Events/Queries/Policies,
# and timestamp support for the persistence layer.
#
#   class Pizza
#     include Hecks::Model
#     attr_reader :name, :toppings
#     def initialize(name: nil, toppings: [])
#       @name = name
#       @toppings = toppings.freeze
#     end
#   end
#
require "securerandom"

module Hecks
  module Model
    def self.included(base)
      base.attr_reader :id, :created_at, :updated_at
      create_submodule(base, :Commands)
      create_submodule(base, :Events)
      create_submodule(base, :Queries)
      create_submodule(base, :Policies)
    end

    # Timestamps — set by persistence layer, not by domain logic
    def stamp_created!
      @created_at = Time.now
      @updated_at = @created_at
    end

    def stamp_updated!
      @updated_at = Time.now
    end

    # Identity

    def ==(other)
      other.is_a?(self.class) && id == other.id
    end
    alias eql? ==

    def hash
      [self.class, id].hash
    end

    private

    def generate_id
      SecureRandom.uuid
    end

    def validate!; end

    def check_invariants!; end

    # Auto-discovery: creates a submodule that autoloads constants by convention.
    # PizzasDomain::Pizza::Commands::CreatePizza
    #   → requires "pizzas_domain/pizza/commands/create_pizza"
    def self.create_submodule(base, type)
      return if base.const_defined?(type, false)

      mod = Module.new
      type_dir = Hecks::Utils.underscore(type.to_s)

      mod.define_singleton_method(:const_missing) do |name|
        parts = base.name.split("::")
        gem_name = Hecks::Utils.underscore(parts.first)
        agg_name = Hecks::Utils.underscore(parts.last)
        file_name = Hecks::Utils.underscore(name.to_s)
        require "#{gem_name}/#{agg_name}/#{type_dir}/#{file_name}"
        const_get(name)
      end

      base.const_set(type, mod)
    end

    private_class_method :create_submodule
  end
end

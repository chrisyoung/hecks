# Hecks::Model
#
# Mixin for generated aggregate classes. Declares attributes via a DSL,
# generates the constructor automatically, and provides identity,
# validation hooks, auto-discovery, and timestamp support.
#
#   class Pizza
#     include Hecks::Model
#     attribute :name
#     attribute :description
#     attribute :toppings, default: []
#   end
#
#   Pizza.hecks_attributes  # => [{name: :name, default: nil}, ...]
#   Pizza.new(name: "Margherita").name  # => "Margherita"
#
require "securerandom"

module Hecks
  module Model
    def self.included(base)
      base.extend(ClassMethods)
      base.attr_reader :id, :created_at, :updated_at
      create_submodule(base, :Commands)
      create_submodule(base, :Events)
      create_submodule(base, :Queries)
      create_submodule(base, :Policies)
      create_submodule(base, :Specifications)
    end

    module ClassMethods
      def attribute(name, default: nil, freeze: false)
        @hecks_attributes ||= []
        @hecks_attributes << { name: name.to_sym, default: default, freeze: freeze }
        attr_reader name
        attr_writer name
        rebuild_initializer
      end

      def hecks_attributes
        @hecks_attributes || []
      end

      private

      def rebuild_initializer
        attrs = @hecks_attributes.dup
        define_method(:initialize) do |id: nil, **kwargs|
          @id = id || SecureRandom.uuid
          @_pristine = {}
          attrs.each do |attr|
            val = kwargs.fetch(attr[:name], attr[:default])
            val = val.freeze if attr[:freeze]
            instance_variable_set(:"@#{attr[:name]}", val)
            @_pristine[attr[:name]] = val
          end
          validate!
          check_invariants!
        end
      end
    end

    # Restore all attributes to their constructor values
    def reset!
      @_pristine.each do |name, val|
        instance_variable_set(:"@#{name}", val)
      end
      self
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

    def validate!; end

    def check_invariants!; end

    MIXINS = {
      Commands:       -> { Hecks::Command },
      Queries:        -> { Hecks::Query },
      Specifications: -> { Hecks::Specification },
    }.freeze

    # Auto-discovery: creates a submodule that autoloads constants by convention
    # and auto-includes the appropriate mixin (Hecks::Command, Hecks::Query).
    def self.create_submodule(base, type)
      return if base.const_defined?(type, false)

      mod = Module.new
      type_dir = Hecks::Utils.underscore(type.to_s)
      mixin_proc = MIXINS[type]

      mod.define_singleton_method(:const_missing) do |name|
        parts = base.name.split("::")
        gem_name = Hecks::Utils.underscore(parts.first)
        agg_name = Hecks::Utils.underscore(parts.last)
        file_name = Hecks::Utils.underscore(name.to_s)

        if mixin_proc
          # Pre-create class with mixin so DSL methods (emits, where, etc.)
          # are available when the file is loaded and reopens the class.
          klass = Class.new
          const_set(name, klass)
          klass.include(mixin_proc.call)
          require "#{gem_name}/#{agg_name}/#{type_dir}/#{file_name}"
          klass
        else
          require "#{gem_name}/#{agg_name}/#{type_dir}/#{file_name}"
          const_get(name)
        end
      end

      base.const_set(type, mod)
    end

    private_class_method :create_submodule
  end
end

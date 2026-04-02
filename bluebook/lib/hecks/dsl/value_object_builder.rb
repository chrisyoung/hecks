module Hecks
  module DSL

    # Hecks::DSL::ValueObjectBuilder
    #
    # DSL builder for value object definitions. Collects attributes and invariants,
    # then builds a DomainModel::Structure::ValueObject. Used inside aggregate blocks.
    #
    # Part of the DSL layer, nested under AggregateBuilder. The resulting value
    # object is embedded within its parent aggregate.
    #
    #   builder = ValueObjectBuilder.new("Address")
    #   builder.attribute :street, String
    #   builder.attribute :city, String
    #   builder.invariant("street required") { !street.nil? }
    #   vo = builder.build  # => #<ValueObject name="Address" ...>
    #
    # Builds a DomainModel::Structure::ValueObject from DSL declarations.
    #
    # ValueObjectBuilder collects attributes and invariants for an immutable,
    # equality-by-value type embedded within an aggregate. Value objects have
    # no identity of their own -- two value objects with the same attribute
    # values are considered equal. They are always immutable; changes produce
    # new instances.
    #
    # Includes AttributeCollector for the +attribute+, +list_of+, and
    # +reference_to+ DSL methods.
    class ValueObjectBuilder
      Structure = DomainModel::Structure

      include AttributeCollector

      # Initialize a new value object builder with the given type name.
      #
      # @param name [String] the value object type name (e.g. "Address", "Money")
      def initialize(name)
        @name = name
        @attributes = []
        @invariants = []
        @functions = []
      end

      # Define an invariant constraint on this value object.
      #
      # Invariants are boolean conditions that must always hold true for the
      # value object to be in a valid state. They are checked at construction.
      #
      # @param message [String] human-readable description of the invariant
      # @yield block that returns true when the invariant holds, false when violated
      # @return [void]
      def invariant(message, &block)
        @invariants << Structure::Invariant.new(message: message, block: block)
      end

      # Declare a side-effect-free function on this value object. The block
      # body becomes a method on the generated class.
      #
      #   function :display do
      #     "#{street}, #{city}"
      #   end
      #
      def function(name, &block)
        @functions << Structure::PureFunction.new(name: name.to_sym, block: block)
      end

      # Implicit DSL: `name Type` → attribute
      def method_missing(name, *args, **kwargs, &block)
        if args.first.is_a?(Class) || (args.first.is_a?(String) && args.first =~ /\A[A-Z]/)
          attribute(name, args.first, **kwargs)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        true
      end

      # Build and return the DomainModel::Structure::ValueObject IR object.
      #
      # @return [DomainModel::Structure::ValueObject] the fully built value object IR object
      def build
        Structure::ValueObject.new(
          name: @name,
          attributes: @attributes,
          invariants: @invariants,
          functions: @functions
        )
      end
    end
  end
end

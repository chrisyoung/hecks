module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::ClosedOperation
    #
    # An operation on a value object that returns a new instance of the same
    # type (closure of operations). This is a core DDD pattern for value
    # objects like Money, Weight, or Distance where arithmetic produces
    # another value of the same kind.
    #
    # The name becomes a Ruby method (typically an operator like :+ or :-)
    # and the block defines the computation. The generated method accepts
    # another instance of the same value object and returns a new one.
    #
    # Part of the DomainModel IR layer. Built by ValueObjectBuilder and
    # consumed by ValueObjectGenerator to produce operator methods.
    #
    #   op = ClosedOperation.new(name: :+, block: proc { |other| ... })
    #   op.name   # => :+
    #   op.block  # => #<Proc>
    #
    class ClosedOperation
      # @return [Symbol] the operator or method name (e.g., :+, :-, :*, :merge)
      attr_reader :name

      # @return [Proc] the block defining the computation. Receives +other+
      #   (another instance of the same value object) and returns constructor
      #   arguments for a new instance.
      attr_reader :block

      # Creates a new ClosedOperation IR node.
      #
      # @param name [Symbol] the operator or method name
      # @param block [Proc] computation block that accepts +other+ and returns
      #   keyword arguments for the value object constructor
      #
      # @return [ClosedOperation] a new ClosedOperation instance
      def initialize(name:, block:)
        @name = name
        @block = block
      end
    end
    end
  end
end

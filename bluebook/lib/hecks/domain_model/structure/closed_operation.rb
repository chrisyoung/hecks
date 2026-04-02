module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::ClosedOperation
    #
    # Intermediate representation of a closed operation on a value object.
    # A closed operation takes operands of the same type and returns a result
    # of the same type (closure of operations in DDD).
    #
    # For example, Money + Money => Money, or DateRange.merge(DateRange) => DateRange.
    #
    # Part of the DomainModel IR layer. Built by ValueObjectBuilder and consumed
    # by ValueObjectGenerator to produce operator methods on the generated class.
    #
    #   op = ClosedOperation.new(name: :add, operator: :+, block: proc { ... })
    #   op.name      # => :add
    #   op.operator  # => :+
    #   op.block     # => #<Proc>
    #
    class ClosedOperation
      # @return [Symbol] the method name for this operation (e.g., :add, :merge)
      attr_reader :name

      # @return [Symbol, nil] the Ruby operator symbol to alias (e.g., :+, :-, :*)
      attr_reader :operator

      # @return [Proc] the block defining the operation logic
      attr_reader :block

      # Creates a new ClosedOperation IR node.
      #
      # @param name [Symbol] the method name (e.g., :add, :merge)
      # @param operator [Symbol, nil] optional Ruby operator to alias
      # @param block [Proc] the operation logic, receives `other` as argument
      # @return [ClosedOperation]
      def initialize(name:, operator: nil, block:)
        @name = name.to_sym
        @operator = operator&.to_sym
        @block = block
      end
    end
    end
  end
end

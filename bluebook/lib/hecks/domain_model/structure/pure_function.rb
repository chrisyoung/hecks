module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::PureFunction
    #
    # Intermediate representation of a side-effect-free function on an
    # aggregate or value object. Pure functions compute a result from the
    # object's attributes without mutating state.
    #
    # Part of the DomainModel IR layer. Built by AggregateBuilder or
    # ValueObjectBuilder and consumed by generators to produce readonly
    # methods on the generated class.
    #
    #   func = PureFunction.new(name: :full_address, block: proc { "#{street}, #{city}" })
    #   func.name   # => :full_address
    #   func.block  # => #<Proc>
    #
    class PureFunction
      # @return [Symbol] the method name for this function
      attr_reader :name

      # @return [Proc] the function body, evaluated in the context of the object
      attr_reader :block

      # Creates a new PureFunction IR node.
      #
      # @param name [Symbol] the method name (e.g., :full_address, :total)
      # @param block [Proc] the function body
      # @return [PureFunction]
      def initialize(name:, block:)
        @name = name.to_sym
        @block = block
      end
    end
    end
  end
end

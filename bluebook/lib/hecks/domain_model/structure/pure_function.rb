module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::PureFunction
    #
    # A side-effect-free function defined on an aggregate or value object.
    # Holds a name and a block whose body becomes a method on the generated
    # class. Pure functions may only read attributes -- they must not mutate
    # state, call commands, or emit events.
    #
    #   PureFunction.new(name: :full_name, block: proc { "#{first} #{last}" })
    #
    class PureFunction
      # @return [Symbol] the name of this pure function
      attr_reader :name

      # @return [Proc] the block whose body computes the return value
      attr_reader :block

      # @param name [Symbol] function name
      # @param block [Proc] computation block referencing attributes
      def initialize(name:, block:)
        @name = name
        @block = block
      end
    end
    end
  end
end

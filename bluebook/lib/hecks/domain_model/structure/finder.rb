module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::Finder
    #
    # Value object representing a custom named finder declared on an aggregate.
    # A finder has a name and a list of parameter names. At runtime, the memory
    # adapter auto-generates an implementation that filters by matching each
    # param against the corresponding attribute. The port module generates
    # a NotImplementedError stub for custom adapters to implement.
    #
    # Part of the DomainModel IR layer. Built by AggregateBuilder and consumed
    # by generators and the querying subsystem at runtime.
    #
    #   Finder.new(name: :by_name, params: [:name])
    #   Finder.new(name: :by_status_and_priority, params: [:status, :priority])
    #
    class Finder
      # @return [Symbol] the finder name, used as a method name on the repository
      #   and aggregate class (e.g., :by_name, :by_status_and_priority)
      attr_reader :name

      # @return [Array<Symbol>] the parameter names for this finder. Each param
      #   corresponds to an attribute on the aggregate that will be matched
      #   for equality when the finder is invoked.
      attr_reader :params

      # Creates a new Finder.
      #
      # @param name [Symbol] the finder name
      # @param params [Array<Symbol>] the parameter names for filtering
      # @return [Finder] a new Finder instance
      def initialize(name:, params:)
        @name = name
        @params = params
      end
    end
    end
  end
end

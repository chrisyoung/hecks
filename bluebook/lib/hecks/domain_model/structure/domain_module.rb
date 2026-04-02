module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::DomainModule
    #
    # Intermediate representation of a logical namespace grouping within a
    # domain. Domain modules group related aggregates together for
    # organizational purposes without affecting runtime behavior.
    #
    # Part of the DomainModel IR layer. Built by DomainBuilder's
    # `domain_module` DSL and consumed by the visualizer and serializer.
    #
    #   mod = DomainModule.new(name: "PolicyManagement", aggregates: ["GovernancePolicy"])
    #   mod.name        # => "PolicyManagement"
    #   mod.aggregates  # => ["GovernancePolicy"]
    #
    class DomainModule
      # @return [String] the module name (e.g., "PolicyManagement")
      attr_reader :name

      # @return [Array<String>] names of aggregates in this module
      attr_reader :aggregates

      # Creates a new DomainModule IR node.
      #
      # @param name [String] the module name
      # @param aggregates [Array<String>] aggregate names in this module
      # @return [DomainModule]
      def initialize(name:, aggregates: [])
        @name = name
        @aggregates = aggregates
      end
    end
    end
  end
end

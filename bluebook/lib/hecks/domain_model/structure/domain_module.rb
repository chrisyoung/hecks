module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::DomainModule
    #
    # A logical namespace grouping within a domain. Groups related aggregates
    # under a named module for visualization and serialization. Aggregates
    # still live flat on the Domain; the module is a categorization overlay.
    #
    #   mod = DomainModule.new(name: "Fulfillment", aggregate_names: ["Order", "Shipment"])
    #   mod.name             # => "Fulfillment"
    #   mod.aggregate_names  # => ["Order", "Shipment"]
    #
    class DomainModule
      # @return [String] the module name (e.g., "Fulfillment", "PolicyManagement")
      attr_reader :name

      # @return [Array<String>] names of aggregates belonging to this module
      attr_reader :aggregate_names

      # Creates a new DomainModule IR node.
      #
      # @param name [String] the module name
      # @param aggregate_names [Array<String>] the aggregate names in this module
      def initialize(name:, aggregate_names: [])
        @name = name
        @aggregate_names = aggregate_names
      end
    end
    end
  end
end

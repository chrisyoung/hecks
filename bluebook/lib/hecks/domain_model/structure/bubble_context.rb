module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::BubbleContext
    #
    # Represents a bounded context boundary within a domain. A bubble context
    # groups related aggregates together, defining a logical sub-boundary
    # inside the domain. This is useful for large domains where aggregates
    # cluster into distinct areas of concern.
    #
    # Bubble contexts are a lightweight alternative to splitting into separate
    # domains. They provide visual grouping, documentation boundaries, and
    # serve as candidates for future domain extraction.
    #
    # Part of the DomainModel IR layer. Built by BubbleContextBuilder and
    # consumed by visualizers and documentation generators.
    #
    #   ctx = BubbleContext.new(
    #     name: "Fulfillment",
    #     aggregate_names: ["Order", "Shipment"],
    #     description: "Handles order fulfillment and shipping"
    #   )
    #   ctx.name             # => "Fulfillment"
    #   ctx.aggregate_names  # => ["Order", "Shipment"]
    #
    class BubbleContext
      # @return [String] the name of this bounded context (e.g., "Fulfillment", "Billing")
      attr_reader :name

      # @return [Array<String>] names of aggregates that belong to this context
      attr_reader :aggregate_names

      # @return [String, nil] optional human-readable description of this context's purpose
      attr_reader :description

      # Creates a new BubbleContext.
      #
      # @param name [String] the context name
      # @param aggregate_names [Array<String>] aggregates grouped under this context
      # @param description [String, nil] optional description
      #
      # @return [BubbleContext] a new BubbleContext instance
      def initialize(name:, aggregate_names: [], description: nil)
        @name = name
        @aggregate_names = aggregate_names
        @description = description
      end
    end
    end
  end
end

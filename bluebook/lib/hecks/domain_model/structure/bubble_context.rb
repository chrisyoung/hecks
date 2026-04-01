module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::BubbleContext
    #
    # A logical sub-boundary within a domain that groups existing aggregates
    # under a named context. Bubble contexts act as anti-corruption layers,
    # presenting a simplified view of a subset of the domain's aggregates.
    #
    # Aggregates are referenced by name; the actual Aggregate IR nodes live
    # on the parent Domain. A BubbleContext is purely organizational metadata.
    #
    #   BubbleContext.new(name: "Fulfillment", aggregate_names: ["Order", "Shipment"])
    #   bc.name             # => "Fulfillment"
    #   bc.aggregate_names  # => ["Order", "Shipment"]
    #
    class BubbleContext
      # @return [String] the context name (e.g. "Fulfillment", "Billing")
      attr_reader :name

      # @return [Array<String>] names of aggregates grouped under this context
      attr_reader :aggregate_names

      def initialize(name:, aggregate_names: [])
        @name = name
        @aggregate_names = aggregate_names
      end
    end
    end
  end
end

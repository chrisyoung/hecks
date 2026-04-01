module Hecks
  module DSL

    # Hecks::DSL::BubbleContextBuilder
    #
    # DSL builder for bubble context definitions. Collects aggregate names
    # and an optional description, then builds a
    # DomainModel::Structure::BubbleContext IR node.
    #
    # Bubble contexts group related aggregates into bounded context boundaries
    # within a single domain. They provide logical sub-boundaries for large
    # domains.
    #
    #   builder = BubbleContextBuilder.new("Fulfillment")
    #   builder.aggregate "Order"
    #   builder.aggregate "Shipment"
    #   builder.description "Handles order fulfillment and shipping"
    #   ctx = builder.build
    #   ctx.aggregate_names  # => ["Order", "Shipment"]
    #
    class BubbleContextBuilder
      Structure = DomainModel::Structure

      def initialize(name)
        @name = name
        @aggregate_names = []
        @description = nil
      end

      # Declare an aggregate as belonging to this bubble context.
      #
      # @param name [String] the aggregate name
      # @return [void]
      def aggregate(name)
        @aggregate_names << name.to_s
      end

      # Set an optional description for this bubble context.
      #
      # @param text [String] the description
      # @return [void]
      def description(text)
        @description = text
      end

      # Build the BubbleContext IR object.
      #
      # @return [DomainModel::Structure::BubbleContext]
      def build
        Structure::BubbleContext.new(
          name: @name,
          aggregate_names: @aggregate_names,
          description: @description
        )
      end
    end
  end
end

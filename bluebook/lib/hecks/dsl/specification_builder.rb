module Hecks
  module DSL

    # Hecks::DSL::SpecificationBuilder
    #
    # DSL builder for specification definitions. Collects a name, optional
    # description, and optional predicate block, then builds a
    # DomainModel::Behavior::Specification IR node.
    #
    # Supports two DSL forms:
    # 1. Block-with-description (declarative):
    #      specification "HighValue" do
    #        description "Orders over $1000"
    #      end
    #
    # 2. Predicate block (executable):
    #      specification "HighValue" do |order|
    #        order.total > 1000
    #      end
    #
    #   builder = SpecificationBuilder.new("HighValue")
    #   builder.description "Orders over $1000"
    #   builder.build  # => Specification IR node
    #
    class SpecificationBuilder
      Behavior = DomainModel::Behavior

      def initialize(name)
        @name = name
        @description = nil
      end

      # Set the human-readable description for this specification.
      #
      # @param text [String] a short description of the business rule
      # @return [void]
      def description(text)
        @description = text
      end

      # Build the Specification IR node.
      #
      # @return [DomainModel::Behavior::Specification]
      def build
        Behavior::Specification.new(
          name: @name,
          description: @description
        )
      end
    end
  end
end

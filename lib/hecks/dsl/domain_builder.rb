# Hecks::DSL::DomainBuilder
#
# Top-level DSL builder for domain definitions. Collects aggregate definitions
# and builds a DomainModel::Structure::Domain. Enforces unique aggregate names.
#
#   Hecks.domain "Pizzas" do
#     aggregate "Pizza" do
#       attribute :name, String
#     end
#   end
#
module Hecks
  module DSL
    class DomainBuilder
      include AttributeCollector

      def initialize(name)
        @name = name
        @aggregates = []
        @attributes = []
      end

      def aggregate(name, &block)
        if @aggregates.any? { |a| a.name == name }
          raise ArgumentError, "Duplicate aggregate name: #{name}"
        end

        builder = AggregateBuilder.new(name)
        builder.instance_eval(&block) if block
        @aggregates << builder.build
      end

      def build
        DomainModel::Structure::Domain.new(name: @name, aggregates: @aggregates)
      end
    end
  end
end

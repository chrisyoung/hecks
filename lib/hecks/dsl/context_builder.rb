# Hecks::DSL::ContextBuilder
#
# DSL builder for bounded contexts. Collects aggregates within a named
# context boundary. Used inside a Hecks.domain block:
#
#   Hecks.domain "Pizzas" do
#     context "Ordering" do
#       aggregate "Order" do
#         attribute :quantity, Integer
#         command "PlaceOrder" do
#           attribute :quantity, Integer
#         end
#       end
#     end
#
#     context "Kitchen" do
#       aggregate "Recipe" do
#         attribute :name, String
#       end
#     end
#   end
#
module Hecks
  module DSL
    class ContextBuilder
      include AttributeCollector

      attr_reader :aggregates

      def initialize(name)
        @name = name
        @aggregates = []
        @attributes = []
      end

      def aggregate(name, &block)
        builder = AggregateBuilder.new(name)
        builder.instance_eval(&block) if block
        @aggregates << builder.build
      end

      def build
        DomainModel::Structure::BoundedContext.new(name: @name, aggregates: @aggregates)
      end
    end
  end
end

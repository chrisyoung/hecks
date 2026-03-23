# Hecks::DSL::DomainBuilder
#
# Top-level DSL builder for domain definitions. Supports both flat aggregate
# definitions (backward compatible) and bounded context groupings:
#
# Flat (single implicit context):
#
#   Hecks.domain "Pizzas" do
#     aggregate "Pizza" do
#       attribute :name, String
#     end
#   end
#
# With bounded contexts:
#
#   Hecks.domain "Pizzas" do
#     context "Ordering" do
#       aggregate "Order" do
#         attribute :quantity, Integer
#       end
#     end
#     context "Kitchen" do
#       aggregate "Recipe" do
#         attribute :name, String
#       end
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
        @contexts = []
        @attributes = []
      end

      def aggregate(name, &block)
        builder = AggregateBuilder.new(name)
        builder.instance_eval(&block) if block
        @aggregates << builder.build
      end

      def context(name, &block)
        builder = ContextBuilder.new(name)
        builder.instance_eval(&block) if block
        @contexts << builder.build
      end

      def build
        if @contexts.any?
          # If there are also bare aggregates, wrap them in a Default context
          if @aggregates.any?
            default_ctx = DomainModel::Structure::BoundedContext.new(name: "Default", aggregates: @aggregates)
            DomainModel::Structure::Domain.new(name: @name, contexts: [default_ctx] + @contexts)
          else
            DomainModel::Structure::Domain.new(name: @name, contexts: @contexts)
          end
        else
          DomainModel::Structure::Domain.new(name: @name, aggregates: @aggregates)
        end
      end
    end
  end
end

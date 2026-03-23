# Hecks::DomainModel::BoundedContext
#
# Represents a bounded context within a domain — a grouping of related
# aggregates that share a common language and boundary. Contexts enforce
# separation: aggregates in different contexts cannot reference each other
# directly, only through domain events.
#
# Created by the DSL:
#
#   Hecks.domain "Pizzas" do
#     context "Ordering" do
#       aggregate "Order" do
#         attribute :quantity, Integer
#       end
#     end
#   end
#
# Or built directly:
#
#   ctx = BoundedContext.new(name: "Ordering", aggregates: [order_agg])
#   ctx.module_name  # => "Ordering"
#   ctx.default?     # => false
#
module Hecks
  module DomainModel
    module Structure
    class BoundedContext
      attr_reader :name, :aggregates

      def initialize(name:, aggregates: [])
        @name = name
        @aggregates = aggregates
      end

      def module_name
        name.gsub(/\s+/, "")
      end

      def default?
        name == "Default"
      end
    end
    end
  end
end

# Hecks::Generators::Domain::QueryGenerator
#
# Generates query classes with Hecks::Query mixin. The call method
# contains the query logic using where/order/limit DSL.
#
#   gen = QueryGenerator.new(query, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class QueryGenerator

      def initialize(query, domain_module:, aggregate_name:)
        @query = query
        @domain_module = domain_module
        @aggregate_name = aggregate_name
      end

      def generate
        lines = []
        lines << "require 'hecks/query'"
        lines << ""
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Queries"
        lines << "      class #{@query.name}"
        lines << "        include Hecks::Query"
        lines << ""
        lines << "        def call#{call_params}"
        lines << "          #{call_body}"
        lines << "        end"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def call_params
        params = block_params
        return "" if params.empty?
        "(#{params.join(", ")})"
      end

      def block_params
        @query.block.parameters.map { |_, name| name.to_s }
      end

      def call_body
        Hecks::Utils.block_source(@query.block)
      end
    end
    end
  end
end

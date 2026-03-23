# Hecks::Generators::QueryGenerator
#
# Generates query classes with a call method. Queries are defined in the
# DSL and auto-wired as class methods on aggregates.
#
#   gen = QueryGenerator.new(query, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n    module Queries\n  ..."
#
module Hecks
  module Generators
    class QueryGenerator
      include ContextAware

      def initialize(query, domain_module:, aggregate_name:, context_module: nil)
        @query = query
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @context_module = context_module
      end

      def generate
        lines = []
        lines.concat(module_open_lines)
        lines << "#{indent}class #{@aggregate_name}"
        lines << "#{indent}  module Queries"
        lines << "#{indent}    class #{@query.name}"
        lines << "#{indent}      def call#{call_params}"
        lines << "#{indent}        #{call_body}"
        lines << "#{indent}      end"
        lines << "#{indent}    end"
        lines << "#{indent}  end"
        lines << "#{indent}end"
        lines.concat(module_close_lines)
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

# Hecks::Generators::Domain::QueryObjectGenerator
#
# Generates query modules for aggregates based on DSL attributes. Each
# scalar attribute gets a by_<attribute> class method. These are always
# included — they are domain queries, not ad-hoc.
#
#   gen = QueryObjectGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  module Queries\n    module PizzaQueries\n  ..."
#
module Hecks
  module Generators
    module Domain
    class QueryObjectGenerator
      include ContextAware

      def initialize(aggregate, domain_module:, context_module: nil)
        @aggregate = aggregate
        @domain_module = domain_module
        @context_module = context_module
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Queries"
        if @context_module
          lines << "    module #{@context_module}"
          lines.concat(query_module_lines(6))
          lines << "    end"
        else
          lines.concat(query_module_lines(4))
        end
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def query_module_lines(indent)
        pad = " " * indent
        lines = []
        lines << "#{pad}module #{@aggregate.name}Queries"
        queryable_attributes.each do |attr|
          name = attr.name
          lines << "#{pad}  def by_#{name}(value)"
          lines << "#{pad}    where(#{name}: value)"
          lines << "#{pad}  end"
          lines << ""
        end
        # Remove trailing blank line
        lines.pop if lines.last == ""
        lines << "#{pad}end"
        lines
      end

      def queryable_attributes
        @aggregate.attributes.reject { |a| a.list? || a.reference? }
      end
    end
    end
  end
end

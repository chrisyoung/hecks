# Hecks::Generators::Domain::QueryObjectGenerator
#
# Generates query modules (e.g. PizzaQueries) under Domain::Queries.
# Each scalar, non-reference attribute gets a by_<attribute> method that
# delegates to where(). These modules are mixed into repositories to
# provide typed finder methods. Part of Generators::Domain, consumed by
# DomainGemGenerator.
#
#   gen = QueryObjectGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  module Queries\n    module PizzaQueries\n  ..."
#
module Hecks
  module Generators
    module Domain
    class QueryObjectGenerator

      def initialize(aggregate, domain_module:)
        @aggregate = aggregate
        @domain_module = domain_module
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Queries"
        lines.concat(query_module_lines(4))
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def query_module_lines(indent)
        pad = " " * indent
        lines = []
        lines << "#{pad}module #{Hecks::Utils.sanitize_constant(@aggregate.name)}Queries"
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

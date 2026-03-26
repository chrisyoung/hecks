# Hecks::Querying
#
# Groups all query-related services: the chainable QueryBuilder,
# AdHocQueries, ScopeMethods, and comparison Operators.
# Querying.bind wires named scopes onto aggregate classes.
# AdHocQueries (where, find_by, order, limit) is bound separately
# by Application during repository setup.
#
#   Querying.bind(agg_class, aggregate)
#
module Hecks
  module Querying
      autoload :QueryBuilder,  "hecks/ports/queries/query_builder"
      autoload :AdHocQueries,  "hecks/ports/queries/ad_hoc_queries"
      autoload :ScopeMethods,  "hecks/ports/queries/scope_methods"
      autoload :Operators,     "hecks/ports/queries/operators"

      def self.bind(klass, aggregate)
        ScopeMethods.bind(klass, aggregate)
      end
  end
end

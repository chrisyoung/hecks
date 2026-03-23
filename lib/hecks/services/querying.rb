# Hecks::Services::Querying
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
  module Services
    module Querying
      autoload :QueryBuilder,  "hecks/services/querying/query_builder"
      autoload :AdHocQueries,  "hecks/services/querying/ad_hoc_queries"
      autoload :ScopeMethods,  "hecks/services/querying/scope_methods"
      autoload :Operators,     "hecks/services/querying/operators"

      def self.bind(klass, aggregate)
        ScopeMethods.bind(klass, aggregate)
      end
    end
  end
end

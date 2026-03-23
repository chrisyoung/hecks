# Hecks::Services::Querying
#
# Groups all query-related services: the chainable QueryBuilder,
# ad-hoc query methods (opt-in), and named scopes.
#
#   Querying.bind(agg_class, aggregate)
#
module Hecks
  module Services
    module Querying
      autoload :QueryBuilder,  "hecks/services/querying/query_builder"
      autoload :AdHocQueries,  "hecks/services/querying/ad_hoc_queries"
      autoload :ScopeMethods,  "hecks/services/querying/scope_methods"

      def self.bind(klass, aggregate)
        ScopeMethods.bind(klass, aggregate)
      end
    end
  end
end

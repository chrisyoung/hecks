# Hecks::Services::Querying::AdHocQueries
#
# Opt-in mixin that provides ActiveRecord-style query methods (where,
# find_by, first, last) on aggregate classes. Enable via include_ad_hoc_queries
# in Hecks.configure, or bind directly:
#
#   Hecks::Services::Querying::AdHocQueries.bind(Pizza, repo)
#
#   Pizza.where(style: "Classic").order(:name).limit(5)
#   Pizza.order(:name).limit(5)
#   Pizza.limit(10).offset(20)
#   Pizza.find_by(name: "Margherita")
#
module Hecks
  module Services
    module Querying
      module AdHocQueries
      def self.bind(klass, repo)
        klass.instance_variable_set(:@__hecks_repo__, repo)
        klass.extend(self)
      end

      def where(**conditions)
        Querying::QueryBuilder.new(@__hecks_repo__).where(**conditions)
      end

      def find_by(**conditions)
        Querying::QueryBuilder.new(@__hecks_repo__).find_by(**conditions)
      end

      def order(key_or_hash)
        Querying::QueryBuilder.new(@__hecks_repo__).order(key_or_hash)
      end

      def limit(n)
        Querying::QueryBuilder.new(@__hecks_repo__).limit(n)
      end

      def offset(n)
        Querying::QueryBuilder.new(@__hecks_repo__).offset(n)
      end

      def first
        all.first
      end

      def last
        all.last
      end
      end
    end
  end
end

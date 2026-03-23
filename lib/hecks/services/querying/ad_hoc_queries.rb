# Hecks::Services::Querying::AdHocQueries
#
# Opt-in mixin that provides ActiveRecord-style query methods (where,
# find_by, first, last) on aggregate classes. All repo references are
# closure-captured for per-application isolation.
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

        klass.define_singleton_method(:where) do |**conditions|
          Querying::QueryBuilder.new(repo).where(**conditions)
        end

        klass.define_singleton_method(:find_by) do |**conditions|
          Querying::QueryBuilder.new(repo).find_by(**conditions)
        end

        klass.define_singleton_method(:order) do |key_or_hash|
          Querying::QueryBuilder.new(repo).order(key_or_hash)
        end

        klass.define_singleton_method(:limit) do |n|
          Querying::QueryBuilder.new(repo).limit(n)
        end

        klass.define_singleton_method(:offset) do |n|
          Querying::QueryBuilder.new(repo).offset(n)
        end
      end
      end
    end
  end
end
